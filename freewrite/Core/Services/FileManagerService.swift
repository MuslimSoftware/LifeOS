
import Foundation

@Observable
class FileManagerService {
    private let fileManager = FileManager.default
    
    let documentsDirectory: URL = {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Freewrite")
        
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("Successfully created Freewrite directory")
            } catch {
                print("Error creating directory: \(error)")
            }
        }
        
        return directory
    }()
    
    func saveEntry(_ entry: HumanEntry, content: String) {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        print("Attempting to save file to: \(fileURL.path)")
        
        let metadata = "---\ndate: \(entry.date)\nyear: \(entry.year)\n---\n"
        let contentWithMetadata = metadata + content
        
        do {
            try contentWithMetadata.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved entry: \(entry.filename)")
        } catch {
            print("Error saving entry: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    func loadEntry(_ entry: HumanEntry) -> String? {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        print("Attempting to load file from: \(fileURL.path)")
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                print("Successfully loaded entry: \(entry.filename)")
                return stripMetadata(from: content)
            } else {
                print("File does not exist: \(entry.filename)")
                return nil
            }
        } catch {
            print("Error loading entry: \(error)")
            print("Error details: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func stripMetadata(from content: String) -> String {
        if content.hasPrefix("---\n") {
            let components = content.components(separatedBy: "---\n")
            if components.count >= 3 {
                return components.dropFirst(2).joined(separator: "---\n")
            }
        }
        return content
    }
    
    private func parseMetadata(from content: String) -> (date: String, year: Int)? {
        guard content.hasPrefix("---\n") else { return nil }
        
        let components = content.components(separatedBy: "---\n")
        guard components.count >= 2 else { return nil }
        
        let metadataBlock = components[1]
        let lines = metadataBlock.components(separatedBy: "\n")
        
        var date: String?
        var year: Int?
        
        for line in lines {
            let parts = line.components(separatedBy: ": ")
            guard parts.count == 2 else { continue }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            
            if key == "date" {
                date = value
            } else if key == "year" {
                year = Int(value)
            }
        }
        
        if let date = date, let year = year {
            return (date, year)
        }
        
        return nil
    }
    
    func loadExistingEntries() -> [HumanEntry] {
        print("Looking for entries in: \(documentsDirectory.path)")
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }
            
            print("Found \(mdFiles.count) .md files")
            
            let entriesWithDates = mdFiles.compactMap { fileURL -> (entry: HumanEntry, date: Date)? in
                let filename = fileURL.lastPathComponent
                print("Processing: \(filename)")
                
                guard let uuidMatch = filename.range(of: "\\[(.*?)\\]", options: .regularExpression),
                      let dateMatch = filename.range(of: "\\[(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})\\]", options: .regularExpression),
                      let uuid = UUID(uuidString: String(filename[uuidMatch].dropFirst().dropLast())) else {
                    print("Failed to extract UUID or date from filename: \(filename)")
                    return nil
                }
                
                let dateString = String(filename[dateMatch].dropFirst().dropLast())
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
                
                guard let fileDate = dateFormatter.date(from: dateString) else {
                    print("Failed to parse date from filename: \(filename)")
                    return nil
                }
                
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    
                    // Try to load date from metadata first
                    var displayDate: String
                    var year: Int
                    
                    if let metadata = parseMetadata(from: content) {
                        displayDate = metadata.date
                        year = metadata.year
                    } else {
                        // Fallback to filename parsing for old entries
                        dateFormatter.dateFormat = "MMM d"
                        displayDate = dateFormatter.string(from: fileDate)
                        
                        let calendar = Calendar.current
                        year = calendar.component(.year, from: fileDate)
                    }
                    
                    let strippedContent = stripMetadata(from: content)
                    let preview = strippedContent
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)
                    
                    return (
                        entry: HumanEntry(
                            id: uuid,
                            date: displayDate,
                            filename: filename,
                            previewText: truncated,
                            year: year
                        ),
                        date: fileDate
                    )
                } catch {
                    print("Error reading file: \(error)")
                    return nil
                }
            }
            
            // Sort by journal entry date (most recent first), not file creation date
            return entriesWithDates
                .sorted { entry1, entry2 in
                    // Parse the display date + year to create sortable dates
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    guard let date1 = dateFormatter.date(from: entry1.entry.date),
                          let date2 = dateFormatter.date(from: entry2.entry.date) else {
                        // Fallback to file date if parsing fails
                        return entry1.date > entry2.date
                    }
                    
                    var components1 = Calendar.current.dateComponents([.month, .day], from: date1)
                    components1.year = entry1.entry.year
                    components1.hour = 12
                    
                    var components2 = Calendar.current.dateComponents([.month, .day], from: date2)
                    components2.year = entry2.entry.year
                    components2.hour = 12
                    
                    guard let fullDate1 = Calendar.current.date(from: components1),
                          let fullDate2 = Calendar.current.date(from: components2) else {
                        return entry1.date > entry2.date
                    }
                    
                    // Sort most recent first
                    return fullDate1 > fullDate2
                }
                .map { $0.entry }
            
        } catch {
            print("Error loading directory contents: \(error)")
            return []
        }
    }
    
    func deleteEntry(_ entry: HumanEntry) throws {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        try fileManager.removeItem(at: fileURL)
        print("Successfully deleted file: \(entry.filename)")
    }
    
    func getPreviewText(for entry: HumanEntry) -> String {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let strippedContent = stripMetadata(from: content)
            let preview = strippedContent
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)
        } catch {
            print("Error updating preview text: \(error)")
            return ""
        }
    }
    
    func entryContainsWelcomeMessage(_ entry: HumanEntry) -> Bool {
        guard let content = loadEntry(entry) else { return false }
        return content.contains("Welcome to Freewrite.")
    }
}
