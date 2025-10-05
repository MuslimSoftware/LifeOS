import Foundation
import SwiftUI

@Observable
class ImportViewModel {
    var importedEntries: [ImportedEntry] = []
    var isProcessing: Bool = false
    var currentFile: String = ""
    var currentProgress: Int = 0
    var totalFiles: Int = 0
    var failedFiles: [(filename: String, error: String)] = []
    var errorMessage: String? = nil
    
    private let importService = ImportService()
    private let fileService: FileManagerService
    private let entryListViewModel: EntryListViewModel
    private var importTask: Task<Void, Never>?
    
    init(fileService: FileManagerService, entryListViewModel: EntryListViewModel) {
        self.fileService = fileService
        self.entryListViewModel = entryListViewModel
    }
    
    func processFiles(_ urls: [URL]) {
        // Reset state
        importedEntries = []
        failedFiles = []
        currentProgress = 0
        totalFiles = urls.count
        currentFile = ""
        errorMessage = nil
        
        importTask = Task { @MainActor in
            isProcessing = true
            
            do {
                _ = try await importService.processFiles(urls) { [weak self] progress in
                    await self?.handleProgress(progress)
                }
            } catch let error as ImportError {
                errorMessage = error.errorDescription
            } catch is CancellationError {
                // Task was cancelled - message already set
            } catch {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            }
            
            isProcessing = false
            currentFile = ""
        }
    }
    
    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        isProcessing = false
        currentFile = ""
        
        if !importedEntries.isEmpty {
            errorMessage = "Import cancelled. \(importedEntries.count) entries were successfully processed."
        } else {
            errorMessage = "Import cancelled by user."
        }
    }
    
    @MainActor
    private func handleProgress(_ progress: ImportProgress) {
        switch progress {
        case .started(let total):
            totalFiles = total
            
        case .processing(let current, _, let filename):
            currentProgress = current
            currentFile = filename
            
        case .completed(let entry, let current, _):
            withAnimation(.easeOut(duration: 0.3)) {
                importedEntries.append(entry)
            }
            currentProgress = current
            
        case .failed(let error, let filename, let current, _):
            let errorDesc = (error as? ImportError)?.errorDescription ?? error.localizedDescription
            failedFiles.append((filename: filename, error: errorDesc))
            currentProgress = current
            
        case .finished(let successful, let failed):
            currentFile = ""
            if failed > 0 && successful > 0 {
                errorMessage = "Import completed with \(failed) failed file(s)."
            } else if successful == 0 && failed > 0 {
                errorMessage = "All files failed to import."
            }
            
        case .cancelled(_, _):
            currentFile = ""
        }
    }
    
    func updateDate(for entry: ImportedEntry, to newDate: Date) {
        if let index = importedEntries.firstIndex(where: { $0.sourceURL == entry.sourceURL && $0.filename == entry.filename }) {
            importedEntries[index].date = newDate
        }
    }
    
    func removeEntry(_ entry: ImportedEntry) {
        importedEntries.removeAll { $0.sourceURL == entry.sourceURL && $0.filename == entry.filename }
    }
    
    func importEntries() {
        for importedEntry in importedEntries {
            let newEntry = HumanEntry.createWithDate(date: importedEntry.date)
            
            entryListViewModel.entries.insert(newEntry, at: 0)
            
            fileService.saveEntry(newEntry, content: importedEntry.text)
            entryListViewModel.updatePreviewText(for: newEntry)
        }
        
        entryListViewModel.entries.sort { entry1, entry2 in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            
            guard let date1 = dateFormatter.date(from: entry1.date),
                  let date2 = dateFormatter.date(from: entry2.date) else {
                return entry1.date > entry2.date
            }
            
            var components1 = Calendar.current.dateComponents([.month, .day], from: date1)
            components1.year = entry1.year
            var components2 = Calendar.current.dateComponents([.month, .day], from: date2)
            components2.year = entry2.year
            
            guard let fullDate1 = Calendar.current.date(from: components1),
                  let fullDate2 = Calendar.current.date(from: components2) else {
                return entry1.date > entry2.date
            }
            
            return fullDate1 > fullDate2
        }
        
        reset()
    }
    
    func reset() {
        importTask?.cancel()
        importTask = nil
        importedEntries = []
        failedFiles = []
        isProcessing = false
        currentFile = ""
        currentProgress = 0
        totalFiles = 0
        errorMessage = nil
    }
}
