
import Foundation

@Observable
class FileManagerService {
    private let fileManager = FileManager.default
    
    let documentsDirectory: URL = {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("LifeOS")

        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("Successfully created LifeOS directory")
            } catch {
                print("Error creating directory: \(error)")
            }
        }

        return directory
    }()
    
    func saveEntry(_ entry: HumanEntry, content: String) {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        let existingContent = loadRawContent(from: fileURL)
        let todoSection = existingContent != nil ? extractTODOSection(from: existingContent!) : ""

        let metadata = "---\ndate: \(entry.date)\nyear: \(entry.year)\n---\n"

        let contentWithMetadata: String
        if !todoSection.isEmpty {
            contentWithMetadata = """
            \(metadata)\(todoSection)
            ## Journal
            \(content)
            """
        } else {
            contentWithMetadata = """
            \(metadata)## TODOs

            ## Journal
            \(content)
            """
        }

        guard let encryptionKey = KeychainService.shared.getOrCreateEncryptionKey() else {
            print("Error: Could not get encryption key")
            return
        }

        guard let encryptedData = EncryptionService.shared.encrypt(contentWithMetadata, with: encryptionKey) else {
            print("Error: Could not encrypt content")
            return
        }

        do {
            try encryptedData.write(to: fileURL, options: .atomic)
        } catch {
            print("Error saving entry: \(error)")
        }
    }
    
    func loadEntry(_ entry: HumanEntry) -> String? {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        guard let content = loadRawContent(from: fileURL) else {
            print("Error loading entry: \(entry.filename)")
            return nil
        }

        return extractJournalSection(from: content)
    }

    private func loadRawContent(from fileURL: URL) -> String? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)

            if let encryptionKey = KeychainService.shared.getOrCreateEncryptionKey(),
               let decryptedContent = EncryptionService.shared.decrypt(data, with: encryptionKey) {
                return decryptedContent
            }

            if let plaintext = String(data: data, encoding: .utf8) {
                print("Warning: Loaded unencrypted file (legacy format): \(fileURL.lastPathComponent)")
                return plaintext
            }

            print("Error: Could not decrypt or read file as plaintext")
            return nil
        } catch {
            print("Error loading file: \(error)")
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
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }
            
            let entriesWithDates = mdFiles.compactMap { fileURL -> (entry: HumanEntry, date: Date)? in
                let filename = fileURL.lastPathComponent

                guard let uuidMatch = filename.range(of: "\\[(.*?)\\]", options: .regularExpression),
                      let dateMatch = filename.range(of: "\\[(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})\\]", options: .regularExpression),
                      let uuid = UUID(uuidString: String(filename[uuidMatch].dropFirst().dropLast())) else {
                    return nil
                }
                
                let dateString = String(filename[dateMatch].dropFirst().dropLast())
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
                
                guard let fileDate = dateFormatter.date(from: dateString) else {
                    return nil
                }

                guard let content = loadRawContent(from: fileURL) else {
                    print("Error reading file: \(filename)")
                    return nil
                }

                var displayDate: String
                var year: Int

                if let metadata = parseMetadata(from: content) {
                    displayDate = metadata.date
                    year = metadata.year
                } else {
                    dateFormatter.dateFormat = "MMM d"
                    displayDate = dateFormatter.string(from: fileDate)

                    let calendar = Calendar.current
                    year = calendar.component(.year, from: fileDate)
                }

                let journalContent = extractJournalSection(from: content)
                let preview = journalContent
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !preview.isEmpty else {
                    return nil
                }

                let truncated = preview.count > 100 ? String(preview.prefix(100)) + "..." : preview

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
            }
            
            let sortedEntries = entriesWithDates
                .sorted { entry1, entry2 in
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")

                    guard let date1 = dateFormatter.date(from: entry1.entry.date),
                          let date2 = dateFormatter.date(from: entry2.entry.date) else {
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

                    return fullDate1 > fullDate2
                }
                .map { $0.entry }

            print("[\(timestamp)] Loaded \(sortedEntries.count) entries")
            return sortedEntries

        } catch {
            print("Error loading directory contents: \(error)")
            return []
        }
    }
    
    func deleteEntry(_ entry: HumanEntry) throws {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        try fileManager.removeItem(at: fileURL)
    }
    
    func getPreviewText(for entry: HumanEntry) -> String {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        guard let content = loadRawContent(from: fileURL) else {
            print("Error updating preview text")
            return ""
        }

        let journalContent = extractJournalSection(from: content)
        let preview = journalContent
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? "" : (preview.count > 100 ? String(preview.prefix(100)) + "..." : preview)
    }
    
    func entryContainsWelcomeMessage(_ entry: HumanEntry) -> Bool {
        guard let content = loadEntry(entry) else { return false }
        return content.contains("Welcome to LifeOS.")
    }
    
    private func extractTODOSection(from content: String) -> String {
        let withoutMetadata = stripMetadata(from: content)
        
        guard let todoRange = withoutMetadata.range(of: "## TODOs\n") else {
            return ""
        }
        
        let startIndex = todoRange.lowerBound
        let endIndex: String.Index
        
        if let journalRange = withoutMetadata.range(of: "## Journal") {
            endIndex = journalRange.lowerBound
        } else {
            endIndex = withoutMetadata.endIndex
        }
        
        return String(withoutMetadata[startIndex..<endIndex])
    }
    
    private func extractJournalSection(from content: String) -> String {
        let withoutMetadata = stripMetadata(from: content)

        guard let journalRange = withoutMetadata.range(of: "## Journal\n") else {
            return withoutMetadata.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let journalContent = String(withoutMetadata[journalRange.upperBound...])
        return journalContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractStickyNoteSection(from content: String) -> String {
        let withoutMetadata = stripMetadata(from: content)

        guard let notesRange = withoutMetadata.range(of: "## Notes\n") else {
            return ""
        }

        let startIndex = notesRange.upperBound
        let endIndex: String.Index

        if let todoRange = withoutMetadata.range(of: "## TODOs") {
            endIndex = todoRange.lowerBound
        } else if let journalRange = withoutMetadata.range(of: "## Journal") {
            endIndex = journalRange.lowerBound
        } else {
            endIndex = withoutMetadata.endIndex
        }

        return String(withoutMetadata[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func loadTODOs(for entry: HumanEntry) -> [TODOItem] {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        guard let content = loadRawContent(from: fileURL) else {
            return []
        }

        let todoSection = extractTODOSection(from: content)
        return parseTODOs(from: todoSection)
    }

    func loadTODOsForDate(date: Date) -> [TODOItem] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        let year = Calendar.current.component(.year, from: date)

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            for fileURL in mdFiles {
                guard let content = loadRawContent(from: fileURL) else {
                    continue
                }

                if let metadata = parseMetadata(from: content),
                   metadata.date == dateString && metadata.year == year {
                    let todoSection = extractTODOSection(from: content)
                    return parseTODOs(from: todoSection)
                }
            }
        } catch {
            print("Error loading TODOs for date: \(error)")
        }

        return []
    }

    func loadStickyNoteForDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        let year = Calendar.current.component(.year, from: date)

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            for fileURL in mdFiles {
                guard let content = loadRawContent(from: fileURL) else {
                    continue
                }

                if let metadata = parseMetadata(from: content),
                   metadata.date == dateString && metadata.year == year {
                    return extractStickyNoteSection(from: content)
                }
            }
        } catch {
            print("Error loading sticky note for date: \(error)")
        }

        return ""
    }

    func findExistingFileForDate(date: Date) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        let year = Calendar.current.component(.year, from: date)

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            for fileURL in mdFiles {
                guard let content = loadRawContent(from: fileURL) else {
                    continue
                }

                if let metadata = parseMetadata(from: content),
                   metadata.date == dateString && metadata.year == year {
                    return fileURL.lastPathComponent
                }
            }
        } catch {
            print("Error finding file for date: \(error)")
        }

        return nil
    }
    
    private func parseTODOs(from todoSection: String) -> [TODOItem] {
        var todos: [TODOItem] = []
        let lines = todoSection.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- [") {
                let completed = trimmed.contains("- [x]")

                var text = trimmed
                    .replacingOccurrences(of: "- [x] ", with: "")
                    .replacingOccurrences(of: "- [ ] ", with: "")
                    .trimmingCharacters(in: .whitespaces)

                var dueTime: Date?

                let timePattern = #"@(\d{1,2}):(\d{2})\s*(AM|PM)"#
                if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

                    let nsString = text as NSString
                    let hourStr = nsString.substring(with: match.range(at: 1))
                    let minuteStr = nsString.substring(with: match.range(at: 2))
                    let periodStr = nsString.substring(with: match.range(at: 3)).uppercased()

                    if var hour = Int(hourStr), let minute = Int(minuteStr) {
                        if periodStr == "PM" && hour != 12 {
                            hour += 12
                        } else if periodStr == "AM" && hour == 12 {
                            hour = 0
                        }

                        var components = DateComponents()
                        components.hour = hour
                        components.minute = minute
                        dueTime = Calendar.current.date(from: components)
                    }

                    text = nsString.replacingCharacters(in: match.range, with: "").trimmingCharacters(in: .whitespaces)
                }

                if !text.isEmpty {
                    todos.append(TODOItem(text: text, completed: completed, dueTime: dueTime))
                }
            }
        }

        return todos
    }
    
    func migrateToEncryption() {
        print("Starting encryption migration...")

        guard let encryptionKey = KeychainService.shared.getOrCreateEncryptionKey() else {
            print("Error: Could not get encryption key for migration")
            return
        }

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            var migratedCount = 0
            var skippedCount = 0
            var errorCount = 0

            for fileURL in mdFiles {
                let data = try Data(contentsOf: fileURL)

                if EncryptionService.shared.decrypt(data, with: encryptionKey) != nil {
                    skippedCount += 1
                    continue
                }

                guard let plaintext = String(data: data, encoding: .utf8) else {
                    print("Error: Could not read file as plaintext: \(fileURL.lastPathComponent)")
                    errorCount += 1
                    continue
                }

                guard let encryptedData = EncryptionService.shared.encrypt(plaintext, with: encryptionKey) else {
                    print("Error: Could not encrypt file: \(fileURL.lastPathComponent)")
                    errorCount += 1
                    continue
                }

                try encryptedData.write(to: fileURL, options: .atomic)
                migratedCount += 1
            }

            print("Migration complete: \(migratedCount) files encrypted, \(skippedCount) already encrypted, \(errorCount) errors")
        } catch {
            print("Error during migration: \(error)")
        }
    }

    func exportAllEntriesPlaintext(to destinationURL: URL) -> Bool {
        guard KeychainService.shared.getOrCreateEncryptionKey() != nil else {
            print("Error: Could not get encryption key for export")
            return false
        }

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

            var exportedCount = 0

            for fileURL in mdFiles {
                guard let content = loadRawContent(from: fileURL) else {
                    print("Warning: Could not decrypt file: \(fileURL.lastPathComponent)")
                    continue
                }

                let exportURL = tempDirectory.appendingPathComponent(fileURL.lastPathComponent)
                try content.write(to: exportURL, atomically: true, encoding: .utf8)
                exportedCount += 1
            }

            let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("export.zip")
            if fileManager.fileExists(atPath: tempZipURL.path) {
                try fileManager.removeItem(at: tempZipURL)
            }

            try createZip(from: tempDirectory, to: tempZipURL)

            try fileManager.moveItem(at: tempZipURL, to: destinationURL)

            try fileManager.removeItem(at: tempDirectory)

            print("Successfully exported \(exportedCount) entries to: \(destinationURL.path)")
            return true
        } catch {
            print("Error exporting entries: \(error)")
            return false
        }
    }

    private func createZip(from sourceDirectory: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = sourceDirectory
        process.arguments = ["-r", "-j", destinationURL.path, "."]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Zip error output: \(errorOutput)")
            throw NSError(domain: "FileManagerService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Zip creation failed: \(errorOutput)"])
        }
    }

    func saveTODOs(_ todos: [TODOItem], for entry: HumanEntry) {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        let existingContent = loadRawContent(from: fileURL)
        let journalSection = existingContent != nil ? extractJournalSection(from: existingContent!) : ""

        let todoLines = todos.map { todo in
            let checkbox = todo.completed ? "[x]" : "[ ]"
            var line = "- \(checkbox) \(todo.text)"

            if let dueTime = todo.dueTime {
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: dueTime)
                let minute = calendar.component(.minute, from: dueTime)

                let period = hour >= 12 ? "PM" : "AM"
                let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)

                line += " @\(displayHour):\(String(format: "%02d", minute)) \(period)"
            }

            return line
        }.joined(separator: "\n")

        let metadata = "---\ndate: \(entry.date)\nyear: \(entry.year)\n---\n"
        let newContent = """
        \(metadata)## TODOs
        \(todoLines)

        ## Journal
        \(journalSection)
        """

        guard let encryptionKey = KeychainService.shared.getOrCreateEncryptionKey() else {
            print("Error: Could not get encryption key")
            return
        }

        guard let encryptedData = EncryptionService.shared.encrypt(newContent, with: encryptionKey) else {
            print("Error: Could not encrypt content")
            return
        }

        do {
            try encryptedData.write(to: fileURL, options: .atomic)
            print("✅ TODOs saved successfully for \(entry.filename)")
        } catch {
            print("❌ Failed to save TODOs: \(error)")
        }
    }

    func saveStickyNote(_ text: String, for entry: HumanEntry) {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        let existingContent = loadRawContent(from: fileURL)
        let journalSection = existingContent != nil ? extractJournalSection(from: existingContent!) : ""
        let todoSection = existingContent != nil ? extractTODOSection(from: existingContent!) : ""

        let metadata = "---\ndate: \(entry.date)\nyear: \(entry.year)\n---\n"
        let newContent = """
        \(metadata)## Notes
        \(text)

        \(todoSection)
        ## Journal
        \(journalSection)
        """

        guard let encryptionKey = KeychainService.shared.getOrCreateEncryptionKey() else {
            print("Error: Could not get encryption key")
            return
        }

        guard let encryptedData = EncryptionService.shared.encrypt(newContent, with: encryptionKey) else {
            print("Error: Could not encrypt content")
            return
        }

        do {
            try encryptedData.write(to: fileURL, options: .atomic)
            print("✅ Sticky note saved successfully for \(entry.filename)")
        } catch {
            print("❌ Failed to save sticky note: \(error)")
        }
    }
}
