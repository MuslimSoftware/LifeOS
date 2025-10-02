
import Foundation
import SwiftUI

@Observable
class EntryListViewModel {
    var entries: [HumanEntry] = []
    var selectedEntryId: UUID? = nil
    var hoveredEntryId: UUID? = nil
    var hoveredTrashId: UUID? = nil
    var hoveredExportId: UUID? = nil
    var showingSidebar = false
    
    private let fileService: FileManagerService
    
    init(fileService: FileManagerService) {
        self.fileService = fileService
    }
    
    func loadExistingEntries() -> String? {
        entries = fileService.loadExistingEntries()
        print("Successfully loaded and sorted \(entries.count) entries")
        
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        
        let hasEmptyEntryToday = entries.contains { entry in
            if let entryDate = parseDateFromDisplayString(entry.date) {
                let entryDayStart = calendar.startOfDay(for: entryDate)
                return calendar.isDate(entryDayStart, inSameDayAs: todayStart) && entry.previewText.isEmpty
            }
            return false
        }
        
        let hasOnlyWelcomeEntry = entries.count == 1 && fileService.entryContainsWelcomeMessage(entries[0])
        
        if entries.isEmpty {
            print("First time user, creating welcome entry")
            return createNewEntry(withWelcomeMessage: true)
        } else if !hasEmptyEntryToday && !hasOnlyWelcomeEntry {
            print("No empty entry for today, creating new entry")
            return createNewEntry(withWelcomeMessage: false)
        } else {
            if let todayEntry = entries.first(where: { entry in
                if let entryDate = parseDateFromDisplayString(entry.date) {
                    let entryDayStart = calendar.startOfDay(for: entryDate)
                    return calendar.isDate(entryDayStart, inSameDayAs: todayStart) && entry.previewText.isEmpty
                }
                return false
            }) {
                selectedEntryId = todayEntry.id
                return loadEntry(entry: todayEntry)
            } else if hasOnlyWelcomeEntry {
                selectedEntryId = entries[0].id
                return loadEntry(entry: entries[0])
            }
        }
        
        return nil
    }
    
    func createNewEntry(withWelcomeMessage: Bool = false) -> String {
        let newEntry = HumanEntry.createNew()
        entries.insert(newEntry, at: 0)
        selectedEntryId = newEntry.id
        
        var text = ""
        
        if withWelcomeMessage {
            if let defaultMessageURL = Bundle.main.url(forResource: "default", withExtension: "md"),
               let defaultMessage = try? String(contentsOf: defaultMessageURL, encoding: .utf8) {
                text = defaultMessage
            }
            fileService.saveEntry(newEntry, content: text)
            updatePreviewText(for: newEntry)
        } else {
            fileService.saveEntry(newEntry, content: text)
        }
        
        return text
    }
    
    func loadEntry(entry: HumanEntry) -> String? {
        return fileService.loadEntry(entry)
    }
    
    func saveEntry(entry: HumanEntry, content: String) {
        fileService.saveEntry(entry, content: content)
        updatePreviewText(for: entry)
    }
    
    func deleteEntry(entry: HumanEntry) -> String? {
        do {
            try fileService.deleteEntry(entry)
            
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries.remove(at: index)
                
                if selectedEntryId == entry.id {
                    if let firstEntry = entries.first {
                        selectedEntryId = firstEntry.id
                        return loadEntry(entry: firstEntry)
                    } else {
                        return createNewEntry()
                    }
                }
            }
        } catch {
            print("Error deleting file: \(error)")
        }
        return nil
    }
    
    func updatePreviewText(for entry: HumanEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].previewText = fileService.getPreviewText(for: entry)
        }
    }
    
    private func parseDateFromDisplayString(_ displayDate: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        if let entryDate = dateFormatter.date(from: displayDate) {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: entryDate)
            components.year = Calendar.current.component(.year, from: Date())
            return Calendar.current.date(from: components)
        }
        return nil
    }
}
