import Foundation
import Vision
import AppKit
import PDFKit

struct ImportedEntry {
    let text: String
    var date: Date
    let filename: String
    let sourceURL: URL
}

class ImportService {
    private let ocrService: OCRServiceProtocol
    private let apiKeyStorage: APIKeyStorageProtocol
    
    init(ocrService: OCRServiceProtocol = OpenAIService(), apiKeyStorage: APIKeyStorageProtocol = KeychainService.shared) {
        self.ocrService = ocrService
        self.apiKeyStorage = apiKeyStorage
    }
    
    func processFiles(_ urls: [URL], onProgress: ProgressCallback? = nil) async throws -> [ImportedEntry] {
        // Check if API key exists (uses cache to avoid repeated keychain prompts)
        guard apiKeyStorage.hasAPIKey() else {
            throw ImportError.noAPIKey
        }
        
        await onProgress?(.started(total: urls.count))
        
        var results: [ImportedEntry] = []
        var errors: [Error] = []
        
        for (index, url) in urls.enumerated() {
            if Task.isCancelled {
                await onProgress?(.cancelled(processed: index, total: urls.count))
                break
            }

            let current = index + 1
            let filename = url.lastPathComponent
            await onProgress?(.processing(current: current, total: urls.count, filename: filename))

            let gotAccess = url.startAccessingSecurityScopedResource()
            defer {
                if gotAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let fileExtension = url.pathExtension.lowercased()

                if fileExtension == "pdf" {
                    let entries = try await processPDFFile(url)
                    results.append(contentsOf: entries)
                    for entry in entries {
                        await onProgress?(.completed(entry: entry, current: current, total: urls.count))
                    }
                } else if ["png", "jpg", "jpeg", "heic", "heif"].contains(fileExtension) {
                    let entry = try await processImageFile(url)
                    results.append(entry)
                    await onProgress?(.completed(entry: entry, current: current, total: urls.count))
                } else {
                    throw ImportError.invalidFileType(fileExtension)
                }
            } catch {
                errors.append(error)
                await onProgress?(.failed(error: error, filename: filename, current: current, total: urls.count))
            }
        }

        await onProgress?(.finished(successful: results.count, failed: errors.count))

        if results.isEmpty && !errors.isEmpty {
            throw errors.first!
        }
        
        return results
    }
    
    private func processImageFile(_ url: URL) async throws -> ImportedEntry {
        guard let image = NSImage(contentsOf: url) else {
            throw ImportError.imageLoadFailed(url)
        }
        
        let extracted: ExtractedContent
        do {
            extracted = try await ocrService.extractText(from: image)
        } catch {
            throw ImportError.extractionFailed(underlying: error)
        }
        
        guard !extracted.text.isEmpty else {
            throw ImportError.noTextFound
        }

        let detectedDate: Date
        if let dateString = extracted.date,
           let date = parseISODate(dateString) ?? detectDate(in: dateString) {
            detectedDate = date
        } else {
            detectedDate = detectDate(in: extracted.text) ?? fileCreationDate(for: url) ?? Date()
        }
        
        return ImportedEntry(
            text: extracted.text,
            date: detectedDate,
            filename: url.lastPathComponent,
            sourceURL: url
        )
    }
    
    private func parseISODate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone.current
        
        if let date = formatter.date(from: dateString) {
            // Adjust to noon to avoid timezone edge cases
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            
            if let noonDate = calendar.date(from: components),
               let finalDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: noonDate) {
                return finalDate
            }
            
            return date
        }
        
        return nil
    }
    
    private func processPDFFile(_ url: URL) async throws -> [ImportedEntry] {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ImportError.pdfLoadFailed(url)
        }
        
        var entries: [ImportedEntry] = []
        var pageErrors: [Error] = []
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            let pageImage = page.thumbnail(of: CGSize(width: 2000, height: 2000), for: .mediaBox)
            
            do {
                let extracted = try await ocrService.extractText(from: pageImage)
                
                guard !extracted.text.isEmpty else { continue }
                
                let detectedDate: Date
                if let dateString = extracted.date,
                   let date = parseISODate(dateString) ?? detectDate(in: dateString) {
                    detectedDate = date
                } else {
                    detectedDate = detectDate(in: extracted.text) ?? fileCreationDate(for: url) ?? Date()
                }
                
                let filename = "\(url.deletingPathExtension().lastPathComponent)_page\(pageIndex + 1)"
                
                entries.append(ImportedEntry(
                    text: extracted.text,
                    date: detectedDate,
                    filename: filename,
                    sourceURL: url
                ))
            } catch {
                pageErrors.append(error)
            }
        }

        if entries.isEmpty {
            throw pageErrors.first ?? ImportError.noTextFound
        }
        
        return entries
    }
    

    
    func detectDate(in text: String) -> Date? {
        let searchText = String(text.prefix(500))
        
        let patterns: [(pattern: String, format: String)] = [
            // Full day of week with short month: "Wednesday, Nov 20, 2019"
            ("(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),?\\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\.?\\s+\\d{1,2},?\\s+\\d{4}", "EEEE, MMM d, yyyy"),
            // Short day of week with short month: "Wed, Nov 20, 2019"
            ("(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),?\\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\.?\\s+\\d{1,2},?\\s+\\d{4}", "EEE, MMM d, yyyy"),
            // Full month name: "October 3, 2024" or "October 3 2024"
            ("(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2},?\\s+\\d{4}", "MMMM d, yyyy"),
            // Short month: "Oct 3, 2024" or "Nov 20, 2019"
            ("(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\.?\\s+\\d{1,2},?\\s+\\d{4}", "MMM d, yyyy"),
            // Numeric with slashes: "10/3/2024"
            ("\\d{1,2}/\\d{1,2}/\\d{4}", "M/d/yyyy"),
            // Numeric with dashes: "10-3-2024"
            ("\\d{1,2}-\\d{1,2}-\\d{4}", "M-d-yyyy"),
            // ISO format: "2024-10-03"
            ("\\d{4}-\\d{2}-\\d{2}", "yyyy-MM-dd")
        ]
        
        for (pattern, dateFormat) in patterns {
            if let range = searchText.range(of: pattern, options: .regularExpression) {
                let dateString = String(searchText[range])
                let formatter = DateFormatter()
                formatter.dateFormat = dateFormat
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone.current
                
                if let date = formatter.date(from: dateString) {
                    // Adjust to noon to avoid timezone edge cases
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.year, .month, .day], from: date)
                    
                    if let noonDate = calendar.date(from: components),
                       let finalDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: noonDate) {
                        return finalDate
                    }
                    
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func fileCreationDate(for url: URL) -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.creationDate] as? Date
        } catch {
            return nil
        }
    }
}
