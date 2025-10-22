
import Foundation
import SwiftUI

@Observable
class EntryListViewModel {
    var entries: [HumanEntry] = []
    var groupedEntries: [EntryGroup] = []
    var selectedEntryId: UUID? = nil
    var hoveredEntryId: UUID? = nil
    var hoveredTrashId: UUID? = nil
    var hoveredExportId: UUID? = nil
    var showingSidebar = false
    
    var expandedYears: Set<Int> = []
    var expandedMonths: Set<String> = []
    
    var draftEntry: HumanEntry? = nil
    
    var isCurrentEntryDraft: Bool {
        guard let draft = draftEntry,
              let selectedId = selectedEntryId else {
            return false
        }
        return draft.id == selectedId
    }

    let fileService: FileManagerService
    
    init(fileService: FileManagerService) {
        self.fileService = fileService
    }
    
    func loadExistingEntries() -> String? {
        entries = fileService.loadExistingEntries()
        groupedEntries = groupEntriesByDate(entries)
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        expandedYears.insert(currentYear)
        expandedMonths.insert("\(currentYear)-\(currentMonth)")
        
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
            return createNewEntry(withWelcomeMessage: true)
        } else if !hasEmptyEntryToday && !hasOnlyWelcomeEntry {
            return createDraftEntry()
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
        
        groupedEntries = groupEntriesByDate(entries)
        
        return text
    }
    
    func createDraftEntry() -> String {
        let newEntry = HumanEntry.createNew()

        draftEntry = newEntry
        selectedEntryId = newEntry.id

        return ""
    }

    func addEntryAndRefresh(_ entry: HumanEntry) {
        entries.insert(entry, at: 0)
        groupedEntries = groupEntriesByDate(entries)
    }

    func loadEntry(entry: HumanEntry) -> String? {
        return fileService.loadEntry(entry)
    }
    
    func saveEntry(entry: HumanEntry, content: String) {
        if let draft = draftEntry, draft.id == entry.id {
            if !content.isEmpty {
                promoteDraftToSaved(entry: entry, content: content)
            }
        } else {
            fileService.saveEntry(entry, content: content)

            if content.count < 20 {
                updatePreviewTextFromContent(for: entry, content: content)
            } else {
                updatePreviewText(for: entry)
            }
        }
    }

    func saveEntryWithoutPreviewUpdate(entry: HumanEntry, content: String) {
        if let draft = draftEntry, draft.id == entry.id {
            if !content.isEmpty {
                promoteDraftToSaved(entry: entry, content: content)
            }
        } else {
            // Only save to disk, skip expensive preview updates during typing
            fileService.saveEntry(entry, content: content)
        }
    }
    
    private func promoteDraftToSaved(entry: HumanEntry, content: String) {
        guard let draft = draftEntry, draft.id == entry.id else {
            return
        }

        fileService.saveEntry(entry, content: content)
        entries.insert(entry, at: 0)
        groupedEntries = groupEntriesByDate(entries)
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        expandedYears.insert(currentYear)
        expandedMonths.insert("\(currentYear)-\(currentMonth)")
        
        updatePreviewTextFromContent(for: entry, content: content)
        draftEntry = nil
    }
    
    func deleteEntry(entry: HumanEntry) -> String? {
        if let draft = draftEntry, draft.id == entry.id {
            draftEntry = nil
            
            if let firstEntry = entries.first {
                selectedEntryId = firstEntry.id
                return loadEntry(entry: firstEntry)
            } else {
                return createDraftEntry()
            }
        }
        
        do {
            try fileService.deleteEntry(entry)
            
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries.remove(at: index)
                groupedEntries = groupEntriesByDate(entries)
                
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
            groupedEntries = groupEntriesByDate(entries)
        }
    }
    
    private func updatePreviewTextFromContent(for entry: HumanEntry, content: String) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            let preview = content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            entries[index].previewText = preview.isEmpty ? "" : (preview.count > 100 ? String(preview.prefix(100)) + "..." : preview)
            groupedEntries = groupEntriesByDate(entries)
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
    
    private func groupEntriesByDate(_ entries: [HumanEntry]) -> [EntryGroup] {
        let calendar = Calendar.current
        
        let yearGroups = Dictionary(grouping: entries) { entry -> Int in
            return entry.year
        }
        
        let groups = yearGroups.map { (year, yearEntries) -> EntryGroup in
            let monthGroups = Dictionary(grouping: yearEntries) { entry -> Int in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                
                guard let date = dateFormatter.date(from: entry.date) else {
                    return 1
                }
                return calendar.component(.month, from: date)
            }
            
            let months = monthGroups.map { (month, monthEntries) -> MonthGroup in
                let monthName = DateFormatter().monthSymbols[month - 1]
                
                let sortedEntries = monthEntries.sorted { entry1, entry2 in
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    guard let date1 = dateFormatter.date(from: entry1.date),
                          let date2 = dateFormatter.date(from: entry2.date) else {
                        return false
                    }
                    
                    var components1 = calendar.dateComponents([.month, .day], from: date1)
                    components1.year = entry1.year
                    var components2 = calendar.dateComponents([.month, .day], from: date2)
                    components2.year = entry2.year
                    
                    guard let fullDate1 = calendar.date(from: components1),
                          let fullDate2 = calendar.date(from: components2) else {
                        return false
                    }
                    
                    return fullDate1 > fullDate2
                }
                
                return MonthGroup(
                    year: year,
                    month: month,
                    monthName: monthName,
                    entries: sortedEntries
                )
            }.sorted { $0.month > $1.month }
            
            return EntryGroup(year: year, months: months)
        }.sorted { $0.year > $1.year }
        
        return groups
    }
    
    func toggleYear(_ year: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedYears.contains(year) {
                expandedYears.remove(year)
                let monthKeys = expandedMonths.filter { $0.hasPrefix("\(year)-") }
                monthKeys.forEach { expandedMonths.remove($0) }
            } else {
                expandedYears.insert(year)
            }
        }
    }
    
    func toggleMonth(_ year: Int, _ month: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            let key = "\(year)-\(month)"
            if expandedMonths.contains(key) {
                expandedMonths.remove(key)
            } else {
                expandedMonths.insert(key)
            }
        }
    }
    
    func expandSectionsForEntry(_ entry: HumanEntry) {
        expandedYears.insert(entry.year)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = dateFormatter.date(from: entry.date) {
            let month = Calendar.current.component(.month, from: date)
            let monthKey = "\(entry.year)-\(month)"
            expandedMonths.insert(monthKey)
        }
    }
}
