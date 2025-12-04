import Foundation

enum BackupImportError: LocalizedError {
    case noMarkdownFiles
    case noValidEntries
    case invalidArchive
    case unzipFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .noMarkdownFiles:
            return "No markdown files were found in the selected backup."
        case .noValidEntries:
            return "The backup didn't contain any entries with valid frontmatter."
        case .invalidArchive:
            return "The backup zip could not be opened."
        case .unzipFailed(let code):
            return "Unzipping the backup failed (code \(code))."
        }
    }
}

struct BackupImportResult {
    let entriesImported: Int
    let todosImported: Int
    let skippedFiles: [String]
}

private struct ParsedBackupEntry {
    let dateString: String
    let year: Int
    let journalText: String
    let notes: String
    let todos: [ParsedBackupTODO]
    let createdAt: Date
}

private struct ParsedBackupTODO {
    let text: String
    let completed: Bool
}

class BackupImportService {
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

    /// Reset the database and import markdown backups from a zip or folder
    func importBackup(from url: URL, resetBeforeImport: Bool = true) async throws -> BackupImportResult {
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer {
            if gotAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if resetBeforeImport {
            try dbService.resetDatabase()
        }
        try dbService.initialize()

        let (workingDirectory, cleanup) = try prepareWorkspace(for: url)
        defer { cleanup?() }

        let markdownFiles = try collectMarkdownFiles(at: workingDirectory)
        guard !markdownFiles.isEmpty else {
            throw BackupImportError.noMarkdownFiles
        }

        var entries: [HumanEntry] = []
        var todos: [TODOItem] = []
        var stickyNotes: [StickyNote] = []
        var skipped: [String] = []

        for file in markdownFiles {
            do {
                guard let parsed = try parseBackupFile(at: file) else {
                    skipped.append(file.lastPathComponent)
                    continue
                }

                if !parsed.journalText.isEmpty {
                    let preview = buildPreview(from: parsed.journalText)

                    let entry = HumanEntry(
                        id: UUID(),
                        date: parsed.dateString,
                        year: parsed.year,
                        journalText: parsed.journalText,
                        previewText: preview,
                        encryptedData: nil,
                        createdAt: parsed.createdAt,
                        updatedAt: parsed.createdAt
                    )
                    entries.append(entry)
                }

                if !parsed.notes.isEmpty {
                    let stickyNote = StickyNote(
                        id: UUID(),
                        date: parsed.createdAt,
                        content: parsed.notes,
                        createdAt: parsed.createdAt,
                        updatedAt: parsed.createdAt
                    )
                    stickyNotes.append(stickyNote)
                }

                for todo in parsed.todos {
                    todos.append(TODOItem(
                        date: parsed.createdAt,
                        text: todo.text,
                        completed: todo.completed,
                        createdAt: parsed.createdAt,
                        dueTime: nil
                    ))
                }
            } catch {
                skipped.append(file.lastPathComponent)
                print("⚠️ Failed to parse \(file.lastPathComponent): \(error)")
            }
        }

        guard !entries.isEmpty || !stickyNotes.isEmpty || !todos.isEmpty else {
            throw BackupImportError.noValidEntries
        }

        if !entries.isEmpty {
            try entryRepo.saveImportedBatch(entries)
        }
        if !stickyNotes.isEmpty {
            try stickyNoteRepo.saveBatch(stickyNotes)
        }
        if !todos.isEmpty {
            try todoRepo.saveBatch(todos)
        }

        return BackupImportResult(
            entriesImported: entries.count,
            todosImported: todos.count,
            skippedFiles: skipped
        )
    }

    // MARK: - Parsing helpers

    private func prepareWorkspace(for url: URL) throws -> (URL, (() -> Void)?) {
        let ext = url.pathExtension.lowercased()
        guard ext == "zip" else { return (url, nil) }

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("LifeOSBackup-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try unzipArchive(at: url, to: tempDir)

        return (tempDir, { try? self.fileManager.removeItem(at: tempDir) })
    }

    private func collectMarkdownFiles(at root: URL) throws -> [URL] {
        var files: [URL] = []

        if let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if ext == "md" || ext == "markdown" {
                    files.append(fileURL)
                }
            }
        }

        if files.isEmpty {
            let ext = root.pathExtension.lowercased()
            if ext == "md" || ext == "markdown" {
                files.append(root)
            }
        }

        return files
    }

    private func unzipArchive(at sourceURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", sourceURL.path, "-d", destinationURL.path]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let code = process.terminationStatus
            throw BackupImportError.unzipFailed(code)
        }
    }

    private func parseBackupFile(at url: URL) throws -> ParsedBackupEntry? {
        let raw = try String(contentsOf: url, encoding: .utf8)
        var lines = raw.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        lines.removeFirst() // drop leading ---

        var metadata: [String: String] = [:]
        while !lines.isEmpty {
            let line = lines.removeFirst()
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                break
            }

            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                metadata[key] = value
            }
        }

        guard let dateString = metadata["date"]?.trimmingCharacters(in: .whitespaces),
              let yearString = metadata["year"]?.trimmingCharacters(in: .whitespaces),
              let year = Int(yearString) else {
            return nil
        }

        let fileAttributes = try? fileManager.attributesOfItem(atPath: url.path)
        let fallbackDate = (fileAttributes?[.creationDate] as? Date) ?? Date()

        let contentResult = extractContent(from: lines)
        let createdAt = parseDate(dateString: dateString, year: year, fallback: fallbackDate)

        if contentResult.journalText.isEmpty && contentResult.notes.isEmpty && contentResult.todos.isEmpty {
            return nil
        }

        return ParsedBackupEntry(
            dateString: dateString,
            year: year,
            journalText: contentResult.journalText,
            notes: contentResult.notes,
            todos: contentResult.todos,
            createdAt: createdAt
        )
    }

    private func extractContent(from lines: [String]) -> (journalText: String, notes: String, todos: [ParsedBackupTODO]) {
        var sectionMap: [String: [String]] = [:]
        var currentSection: String = "journal"
        var todos: [ParsedBackupTODO] = []

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

        return (journalText, notes, todos)
    }

    private func parseTodoLine(_ line: String) -> ParsedBackupTODO? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("- [") else { return nil }

        let completed = trimmed.lowercased().contains("[x]")
        guard let closing = trimmed.firstIndex(of: "]") else { return nil }

        let text = trimmed[trimmed.index(after: closing)...].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        return ParsedBackupTODO(text: text, completed: completed)
    }

    private func parseDate(dateString: String, year: Int, fallback: Date) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let base = formatter.date(from: dateString.trimmingCharacters(in: .whitespaces)) else {
            return fallback
        }

        var components = Calendar.current.dateComponents([.month, .day], from: base)
        components.year = year

        guard let combined = Calendar.current.date(from: components) else {
            return fallback
        }

        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: combined) ?? combined
    }

    private func buildPreview(from text: String) -> String {
        let preview = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !preview.isEmpty else { return "" }
        return preview.count > 100 ? String(preview.prefix(100)) + "..." : preview
    }
}
