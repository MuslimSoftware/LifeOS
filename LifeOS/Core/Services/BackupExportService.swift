import Foundation
import AppKit
import UniformTypeIdentifiers

enum BackupExportError: LocalizedError {
    case noDataToExport
    case fileWriteFailed(String)
    case zipFailed(Int32)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .noDataToExport:
            return "No data available to export."
        case .fileWriteFailed(let filename):
            return "Failed to write file: \(filename)"
        case .zipFailed(let code):
            return "ZIP creation failed (code \(code))."
        case .userCancelled:
            return "Export cancelled by user."
        }
    }
}

struct BackupExportResult {
    let filesExported: Int
    let dateRange: (start: Date, end: Date)?
    let exportPath: String
}

private struct DayData {
    let date: Date
    var journalEntry: HumanEntry?
    var todos: [TODOItem] = []
    var stickyNote: StickyNote?
}

class BackupExportService {
    private let dbService: DatabaseService
    private let entryRepo: EntryRepository
    private let todoRepo: TODORepository
    private let stickyNoteRepo: StickyNoteRepository
    private let fileManager = FileManager.default

    init(
        dbService: DatabaseService = .shared,
        entryRepo: EntryRepository = EntryRepository(),
        todoRepo: TODORepository = TODORepository(),
        stickyNoteRepo: StickyNoteRepository = StickyNoteRepository()
    ) {
        self.dbService = dbService
        self.entryRepo = entryRepo
        self.todoRepo = todoRepo
        self.stickyNoteRepo = stickyNoteRepo
    }

    func exportBackup() async throws -> BackupExportResult {
        let dayDataList = try fetchAllData()

        guard !dayDataList.isEmpty else {
            throw BackupExportError.noDataToExport
        }

        guard let saveURL = await showSavePanel() else {
            throw BackupExportError.userCancelled
        }

        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("LifeOSExport-\(UUID().uuidString)")

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        try writeMarkdownFiles(dayDataList: dayDataList, to: tempDir)

        try createZipArchive(at: tempDir, destinationURL: saveURL)

        let dateRange = calculateDateRange(from: dayDataList)

        return BackupExportResult(
            filesExported: dayDataList.count,
            dateRange: dateRange,
            exportPath: saveURL.path
        )
    }

    private func fetchAllData() throws -> [DayData] {
        let entries = try entryRepo.getAllEntries()
        let todos = try todoRepo.getAllTODOs()
        let stickyNotes = try stickyNoteRepo.getAllStickyNotes()

        return groupDataByDay(entries: entries, todos: todos, stickyNotes: stickyNotes)
    }

    private func groupDataByDay(
        entries: [HumanEntry],
        todos: [TODOItem],
        stickyNotes: [StickyNote]
    ) -> [DayData] {
        var dayMap: [Date: DayData] = [:]
        let calendar = Calendar.current

        for entry in entries {
            if let entryDate = parseEntryDate(dateString: entry.date, year: entry.year) {
                let dayStart = calendar.startOfDay(for: entryDate)
                if dayMap[dayStart] == nil {
                    dayMap[dayStart] = DayData(date: dayStart)
                }
                dayMap[dayStart]?.journalEntry = entry
            }
        }

        for todo in todos {
            let dayStart = calendar.startOfDay(for: todo.date)
            if dayMap[dayStart] == nil {
                dayMap[dayStart] = DayData(date: dayStart)
            }
            dayMap[dayStart]?.todos.append(todo)
        }

        for note in stickyNotes {
            let dayStart = calendar.startOfDay(for: note.date)
            if dayMap[dayStart] == nil {
                dayMap[dayStart] = DayData(date: dayStart)
            }
            dayMap[dayStart]?.stickyNote = note
        }

        return dayMap.values
            .filter { dayData in
                let hasJournal = dayData.journalEntry != nil && !(dayData.journalEntry?.journalText.isEmpty ?? true)
                let hasTodos = !dayData.todos.isEmpty
                let hasNote = dayData.stickyNote != nil && !(dayData.stickyNote?.content.isEmpty ?? true)
                return hasJournal || hasTodos || hasNote
            }
            .sorted { $0.date < $1.date }
    }

    private func parseEntryDate(dateString: String, year: Int) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let base = formatter.date(from: dateString) else {
            return nil
        }

        var components = Calendar.current.dateComponents([.month, .day], from: base)
        components.year = year

        return Calendar.current.date(from: components)
    }

    private func generateMarkdownFile(for dayData: DayData) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: dayData.date)

        let year = Calendar.current.component(.year, from: dayData.date)

        var content = """
        ---
        date: \(dateString)
        year: \(year)
        ---

        """

        if let entry = dayData.journalEntry, !entry.journalText.isEmpty {
            content += entry.journalText
            content += "\n\n"
        }

        if let note = dayData.stickyNote, !note.content.isEmpty {
            content += "## Notes\n"
            content += note.content
            content += "\n\n"
        }

        if !dayData.todos.isEmpty {
            content += "## TODOs\n"
            for todo in dayData.todos {
                let checkbox = todo.completed ? "[x]" : "[ ]"
                content += "- \(checkbox) \(todo.text)\n"
            }
        }

        return content
    }

    private func writeMarkdownFiles(dayDataList: [DayData], to directory: URL) throws {
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"

        for dayData in dayDataList {
            let filename = isoFormatter.string(from: dayData.date) + ".md"
            let fileURL = directory.appendingPathComponent(filename)
            let content = generateMarkdownFile(for: dayData)

            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                throw BackupExportError.fileWriteFailed(filename)
            }
        }
    }

    private func createZipArchive(at sourceDirectory: URL, destinationURL: URL) throws {
        let markdownFiles = try fileManager.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }

        guard !markdownFiles.isEmpty else {
            throw BackupExportError.noDataToExport
        }

        let tempZipURL = sourceDirectory.appendingPathComponent("backup.zip")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")

        var arguments = ["-j", tempZipURL.path]
        arguments.append(contentsOf: markdownFiles.map { $0.path })
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = try? stderr.fileHandleForReading.readToEnd()
            let errorString = errorData.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
            print("ZIP error: \(errorString)")
            throw BackupExportError.zipFailed(process.terminationStatus)
        }

        try fileManager.copyItem(at: tempZipURL, to: destinationURL)
    }

    @MainActor
    private func showSavePanel() -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.zip]
        savePanel.nameFieldStringValue = "LifeOS-Backup-\(dateStringForFilename()).zip"
        savePanel.isExtensionHidden = false
        savePanel.title = "Export Backup"
        savePanel.message = "Choose where to save your backup"

        guard savePanel.runModal() == .OK else {
            return nil
        }

        return savePanel.url
    }

    private func dateStringForFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func calculateDateRange(from dayDataList: [DayData]) -> (start: Date, end: Date)? {
        guard let first = dayDataList.first?.date,
              let last = dayDataList.last?.date else {
            return nil
        }
        return (start: first, end: last)
    }
}
