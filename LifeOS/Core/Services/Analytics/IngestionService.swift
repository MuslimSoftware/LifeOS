import Foundation

/// Service for chunking journal entries into semantic segments
/// Splits text intelligently while respecting paragraph boundaries and sentence structure
class IngestionService {

    // MARK: - Configuration

    /// Target token count per chunk (700-1000 tokens)
    private let targetTokenCount = 850
    private let minTokenCount = 700
    private let maxTokenCount = 1000

    private let charsPerToken = 4

    // MARK: - Public API

    func chunkEntry(entry: HumanEntry, content: String) throws -> [JournalChunk] {
        guard !content.isEmpty else {
            return []
        }

        let entryDate = parseEntryDate(entry: entry)

        let paragraphs = content.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [JournalChunk] = []
        var currentChunk = ""
        var currentStartChar = 0
        var currentCharPosition = 0

        for paragraph in paragraphs {
            let paragraphTokens = estimateTokenCount(paragraph)
            let currentTokens = estimateTokenCount(currentChunk)

            if currentTokens + paragraphTokens > maxTokenCount && !currentChunk.isEmpty {
                let chunk = createChunk(
                    text: currentChunk,
                    entryId: entry.id,
                    startChar: currentStartChar,
                    endChar: currentCharPosition,
                    date: entryDate
                )
                chunks.append(chunk)

                currentChunk = paragraph
                currentStartChar = currentCharPosition
            } else {
                if !currentChunk.isEmpty {
                    currentChunk += "\n\n"
                    currentCharPosition += 2
                }
                currentChunk += paragraph
            }

            currentCharPosition += paragraph.count + 2

            let tokens = estimateTokenCount(currentChunk)
            if tokens >= targetTokenCount {
                let chunk = createChunk(
                    text: currentChunk,
                    entryId: entry.id,
                    startChar: currentStartChar,
                    endChar: currentCharPosition,
                    date: entryDate
                )
                chunks.append(chunk)

                currentChunk = ""
                currentStartChar = currentCharPosition
            }
        }

        if !currentChunk.isEmpty {
            let chunk = createChunk(
                text: currentChunk,
                entryId: entry.id,
                startChar: currentStartChar,
                endChar: currentCharPosition,
                date: entryDate
            )
            chunks.append(chunk)
        }

        if chunks.isEmpty && !content.isEmpty {
            let chunk = createChunk(
                text: content,
                entryId: entry.id,
                startChar: 0,
                endChar: content.count,
                date: entryDate
            )
            chunks.append(chunk)
        }

        return chunks
    }

    // MARK: - Private Helpers

    private func estimateTokenCount(_ text: String) -> Int {
        return text.count / charsPerToken
    }

    private func createChunk(
        text: String,
        entryId: UUID,
        startChar: Int,
        endChar: Int,
        date: Date
    ) -> JournalChunk {
        let tokenCount = estimateTokenCount(text)

        return JournalChunk(
            entryId: entryId,
            text: text,
            embedding: nil,
            startChar: startChar,
            endChar: endChar,
            date: date,
            tokenCount: tokenCount
        )
    }

    private func parseEntryDate(entry: HumanEntry) -> Date {
        let filename = entry.filename

        if let startBracket = filename.lastIndex(of: "["),
           let endBracket = filename.lastIndex(of: "]") {
            let dateRange = filename.index(after: startBracket)..<endBracket
            let dateString = String(filename[dateRange])

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"

            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return Date()
    }
}
