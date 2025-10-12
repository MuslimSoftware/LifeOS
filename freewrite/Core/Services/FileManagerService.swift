
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
        
        let existingContent = try? String(contentsOf: fileURL, encoding: .utf8)
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
                return extractJournalSection(from: content)
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
                    
                    let journalContent = extractJournalSection(from: content)
                    let preview = journalContent
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !preview.isEmpty else {
                        print("Skipping TODO-only entry: \(filename)")
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
            let journalContent = extractJournalSection(from: content)
            let preview = journalContent
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty ? "" : (preview.count > 100 ? String(preview.prefix(100)) + "..." : preview)
        } catch {
            print("Error updating preview text: \(error)")
            return ""
        }
    }
    
    func entryContainsWelcomeMessage(_ entry: HumanEntry) -> Bool {
        guard let content = loadEntry(entry) else { return false }
        return content.contains("Welcome to Freewrite.")
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
    
    func loadTODOs(for entry: HumanEntry) -> [TODOItem] {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        guard fileManager.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
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
                let content = try String(contentsOf: fileURL, encoding: .utf8)
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

    func findExistingFileForDate(date: Date) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        let year = Calendar.current.component(.year, from: date)

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            for fileURL in mdFiles {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
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

                // Parse time in format @H:MM AM/PM or @HH:MM AM/PM
                let timePattern = #"@(\d{1,2}):(\d{2})\s*(AM|PM)"#
                if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

                    let nsString = text as NSString
                    let hourStr = nsString.substring(with: match.range(at: 1))
                    let minuteStr = nsString.substring(with: match.range(at: 2))
                    let periodStr = nsString.substring(with: match.range(at: 3)).uppercased()

                    if var hour = Int(hourStr), let minute = Int(minuteStr) {
                        // Convert to 24-hour format
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

                    // Remove time from text
                    text = nsString.replacingCharacters(in: match.range, with: "").trimmingCharacters(in: .whitespaces)
                }

                if !text.isEmpty {
                    todos.append(TODOItem(text: text, completed: completed, dueTime: dueTime))
                }
            }
        }

        return todos
    }
    
    func saveTODOs(_ todos: [TODOItem], for entry: HumanEntry) {
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        let existingContent = try? String(contentsOf: fileURL, encoding: .utf8)
        let journalSection = existingContent != nil ? extractJournalSection(from: existingContent!) : ""

        let todoLines = todos.map { todo in
            let checkbox = todo.completed ? "[x]" : "[ ]"
            var line = "- \(checkbox) \(todo.text)"

            if let dueTime = todo.dueTime {
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: dueTime)
                let minute = calendar.component(.minute, from: dueTime)

                // Convert to 12-hour format
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
        
        do {
            try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved TODOs for: \(entry.filename)")
        } catch {
            print("Error saving TODOs: \(error)")
        }
    }
}
