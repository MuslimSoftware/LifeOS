import Foundation
import SwiftUI
import GRDB

@Observable
class EntryListViewModel {
    var entries: [HumanEntry] = []
    var groupedEntries: [EntryGroup] = []
    var selectedEntryId: UUID? = nil
    var hoveredEntryId: UUID? = nil
    var hoveredTrashId: UUID? = nil
    var hoveredExportId: UUID? = nil

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

    let entryRepo: EntryRepository
    let todoRepo: TODORepository
    let stickyRepo: StickyNoteRepository
    let chunkRepository: ChunkRepository

    init(entryRepo: EntryRepository, todoRepo: TODORepository, stickyRepo: StickyNoteRepository, chunkRepository: ChunkRepository) {
        self.entryRepo = entryRepo
        self.todoRepo = todoRepo
        self.stickyRepo = stickyRepo
        self.chunkRepository = chunkRepository
    }

    private struct ParsedEntryContent {
        let journalText: String
        let notes: String
        let todos: [ParsedTODO]
        let isEmpty: Bool
    }

    private struct ParsedTODO {
        let text: String
        let completed: Bool
    }

    private func parseEntryContent(_ text: String) -> ParsedEntryContent {
        let lines = text.components(separatedBy: .newlines)
        var sectionMap: [String: [String]] = [:]
        var currentSection: String = "journal"
        var todos: [ParsedTODO] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("##") {
                var title = trimmed
                while title.hasPrefix("#") || title.hasPrefix(" ") {
                    title.removeFirst()
                }
                currentSection = title.trimmingCharacters(in: .whitespaces).lowercased()
                sectionMap[currentSection, default: []] = []
                continue
            }

            sectionMap[currentSection, default: []].append(line)

            if currentSection.contains("todo"),
               let todo = parseTodoLine(trimmed) {
                todos.append(todo)
            }
        }

        let journalText = sectionMap["journal"]?
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let notes = sectionMap["notes"]?
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let isEmpty = journalText.isEmpty && notes.isEmpty && todos.isEmpty

        return ParsedEntryContent(
            journalText: journalText,
            notes: notes,
            todos: todos,
            isEmpty: isEmpty
        )
    }

    private func parseTodoLine(_ line: String) -> ParsedTODO? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("- [") else { return nil }

        let completed = trimmed.lowercased().contains("[x]")
        guard let closing = trimmed.firstIndex(of: "]") else { return nil }

        let text = trimmed[trimmed.index(after: closing)...].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        return ParsedTODO(text: text, completed: completed)
    }

    func loadExistingEntries() -> String? {
        prepareDatabase()

        do {
            entries = try entryRepo.getAllEntries()
        } catch {
            print("Error loading entries: \(error)")
            entries = []
        }

        entries.removeAll { entry in
            entry.journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        groupedEntries = groupEntriesByDate(entries)

        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        expandedYears.insert(currentYear)
        expandedMonths.insert("\(currentYear)-\(currentMonth)")

        if entries.isEmpty {
            return createNewEntry(withWelcomeMessage: true)
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        if let todayEntry = entries.first(where: { isEntry($0, onSameDayAs: todayStart) }) {
            selectedEntryId = todayEntry.id
            expandSectionsForEntry(todayEntry)
            return todayEntry.journalText
        }

        if let latestEntry = entries.first {
            selectedEntryId = latestEntry.id
            expandSectionsForEntry(latestEntry)
            return latestEntry.journalText
        }

        return createNewEntry(withWelcomeMessage: true)
    }
    
    func createNewEntry(withWelcomeMessage: Bool = false) -> String {
        var newEntry = HumanEntry.createNew()
        var text = ""

        if withWelcomeMessage {
            if let defaultMessageURL = Bundle.main.url(forResource: "default", withExtension: "md"),
               let defaultMessage = try? String(contentsOf: defaultMessageURL, encoding: .utf8) {
                text = defaultMessage
            }
            newEntry.journalText = text
            let preview = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            newEntry.previewText = preview.isEmpty ? "" : (preview.count > 100 ? String(preview.prefix(100)) + "..." : preview)
        }

        do {
            try entryRepo.save(newEntry)
            entries.insert(newEntry, at: 0)
            selectedEntryId = newEntry.id
            groupedEntries = groupEntriesByDate(entries)
        } catch {
            print("Error creating entry: \(error)")
        }

        return text
    }
    
    func createDraftEntry() -> String {
        let newEntry = HumanEntry.createNew()

        draftEntry = newEntry
        selectedEntryId = newEntry.id

        return ""
    }
    
    func importEntries(_ importedEntries: [ImportedEntry]) {
        do {
            try DatabaseService.shared.initialize()
        } catch {
            print("⚠️ Failed to initialize database for import: \(error)")
        }

        for imported in importedEntries {
            print("🔍 DEBUG: Parsing entry: \(imported.filename)")
            print("🔍 DEBUG: Raw text length: \(imported.text.count)")

            let parsed = parseEntryContent(imported.text)

            print("🔍 DEBUG: Parsed - Journal: \(parsed.journalText.count) chars")
            print("🔍 DEBUG: Parsed - Notes: \(parsed.notes.count) chars")
            print("🔍 DEBUG: Parsed - TODOs: \(parsed.todos.count) items")
            print("🔍 DEBUG: Parsed - isEmpty: \(parsed.isEmpty)")

            if parsed.isEmpty {
                print("⏭️ Skipping empty entry: \(imported.filename)")
                continue
            }

            var newEntry = HumanEntry.createWithDate(date: imported.date)
            newEntry.journalText = parsed.journalText

            let previewSource = !parsed.journalText.isEmpty ? parsed.journalText :
                                !parsed.notes.isEmpty ? "Notes: \(parsed.notes)" :
                                parsed.todos.map { $0.text }.joined(separator: ", ")
            let preview = previewSource
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            newEntry.previewText = preview.isEmpty ? "" :
                (preview.count > 100 ? String(preview.prefix(100)) + "..." : preview)

            do {
                try entryRepo.save(newEntry)
                entries.append(newEntry)

                if !parsed.notes.isEmpty {
                    let stickyNote = StickyNote(
                        id: UUID(),
                        date: imported.date,
                        content: parsed.notes,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    try stickyRepo.save(stickyNote)
                }

                for parsedTodo in parsed.todos {
                    let todo = TODOItem(
                        id: UUID(),
                        date: imported.date,
                        text: parsedTodo.text,
                        completed: parsedTodo.completed,
                        createdAt: Date(),
                        dueTime: nil
                    )
                    try todoRepo.save(todo)
                }
            } catch {
                print("⚠️ Failed to save imported entry \(imported.filename): \(error)")
            }
        }

        entries.sort { $0.createdAt > $1.createdAt }
        groupedEntries = groupEntriesByDate(entries)
    }

    func addEntryAndRefresh(_ entry: HumanEntry) {
        entries.insert(entry, at: 0)
        groupedEntries = groupEntriesByDate(entries)
    }

    func loadEntry(entry: HumanEntry) -> String? {
        let trimmed = entry.journalText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return entry.journalText
        }

        do {
            guard let loadedEntry = try entryRepo.getEntry(id: entry.id) else {
                return nil
            }
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index] = loadedEntry
                groupedEntries = groupEntriesByDate(entries)
            }
            return loadedEntry.journalText
        } catch {
            print("Error loading entry: \(error)")
            return nil
        }
    }
    
    func saveEntry(entry: HumanEntry, content: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContent.count > 0 else { return }

        if let draft = draftEntry, draft.id == entry.id {
            promoteDraftToSaved(entry: entry, content: content)
        } else {
            var updatedEntry = entry
            updatedEntry.journalText = content

            if content.count < 20 {
                let preview = content.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                updatedEntry.previewText = preview.isEmpty ? "" : (preview.count > 100 ? String(preview.prefix(100)) + "..." : preview)
            } else {
                let preview = content.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                updatedEntry.previewText = preview.isEmpty ? "" : (preview.count > 100 ? String(preview.prefix(100)) + "..." : preview)
            }

            do {
                try entryRepo.save(updatedEntry)
                if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries[index] = updatedEntry
                    groupedEntries = groupEntriesByDate(entries)
                }
            } catch {
                print("Error saving entry: \(error)")
            }
        }
    }

    func saveEntryWithoutPreviewUpdate(entry: HumanEntry, content: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContent.count > 0 else { return }

        if let draft = draftEntry, draft.id == entry.id {
            promoteDraftToSaved(entry: entry, content: content)
        } else {
            var updatedEntry = entry
            updatedEntry.journalText = content

            do {
                try entryRepo.save(updatedEntry)
            } catch {
                print("Error saving entry: \(error)")
            }
        }
    }
    
    private func promoteDraftToSaved(entry: HumanEntry, content: String) {
        guard let draft = draftEntry, draft.id == entry.id else {
            return
        }

        var updatedEntry = entry
        updatedEntry.journalText = content
        let preview = content.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        updatedEntry.previewText = preview.isEmpty ? "" : (preview.count > 100 ? String(preview.prefix(100)) + "..." : preview)

        do {
            try entryRepo.save(updatedEntry)
            entries.insert(updatedEntry, at: 0)
            groupedEntries = groupEntriesByDate(entries)

            let currentYear = Calendar.current.component(.year, from: Date())
            let currentMonth = Calendar.current.component(.month, from: Date())
            expandedYears.insert(currentYear)
            expandedMonths.insert("\(currentYear)-\(currentMonth)")

            draftEntry = nil
        } catch {
            print("Error promoting draft to saved: \(error)")
        }
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
            try? chunkRepository.deleteChunks(forEntryId: entry.id)
            try entryRepo.delete(id: entry.id)

            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries.remove(at: index)
                groupedEntries = groupEntriesByDate(entries)

                if selectedEntryId == entry.id {
                    if let firstEntry = entries.first {
                        selectedEntryId = firstEntry.id
                        return loadEntry(entry: firstEntry)
                    } else {
                        return createDraftEntry()
                    }
                }
            }
        } catch {
            print("Error deleting entry: \(error)")
        }
        return nil
    }
    
    func updatePreviewText(for entry: HumanEntry) {
        do {
            guard let loadedEntry = try entryRepo.getEntry(id: entry.id) else { return }
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                let preview = loadedEntry.journalText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                entries[index].previewText = preview.isEmpty ? "" : (preview.count > 100 ? String(preview.prefix(100)) + "..." : preview)
                groupedEntries = groupEntriesByDate(entries)
            }
        } catch {
            print("Error updating preview text: \(error)")
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
    
    private func prepareDatabase() {
        do {
            try DatabaseService.shared.initialize()
        } catch {
            print("⚠️ Failed to initialize database: \(error)")
        }
    }


    private func isEntry(_ entry: HumanEntry, onSameDayAs date: Date) -> Bool {
        guard let entryDate = buildDate(from: entry) else { return false }
        let calendar = Calendar.current
        let entryDayStart = calendar.startOfDay(for: entryDate)
        return calendar.isDate(entryDayStart, inSameDayAs: date)
    }

    private func buildDate(from entry: HumanEntry) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        guard let baseDate = dateFormatter.date(from: entry.date) else { return nil }

        var components = Calendar.current.dateComponents([.month, .day], from: baseDate)
        components.year = entry.year
        return Calendar.current.date(from: components)
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
