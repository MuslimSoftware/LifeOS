import Foundation

struct ParsedEntryContent {
    let journalText: String
    let notes: String
    let todos: [ParsedTODO]
    let isEmpty: Bool
}

struct ParsedTODO {
    let text: String
    let completed: Bool
}

enum EntryContentParser {
    static func parse(_ text: String) -> ParsedEntryContent {
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

    private static func parseTodoLine(_ line: String) -> ParsedTODO? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("- [") else { return nil }

        let completed = trimmed.lowercased().contains("[x]")
        guard let closing = trimmed.firstIndex(of: "]") else { return nil }

        let text = trimmed[trimmed.index(after: closing)...].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        return ParsedTODO(text: text, completed: completed)
    }
}
