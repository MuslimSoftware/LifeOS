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
    private let entryListViewModel: EntryListViewModel
    private var importTask: Task<Void, Never>?
    
    init(entryListViewModel: EntryListViewModel) {
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
                    self?.handleProgress(progress)
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
        entryListViewModel.importEntries(importedEntries)
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
