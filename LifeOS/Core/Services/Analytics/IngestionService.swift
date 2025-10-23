import Foundation

/// Service for chunking journal entries into semantic segments
/// Splits text intelligently while respecting paragraph boundaries and sentence structure
class IngestionService {

    // MARK: - Configuration

    /// Target token count per chunk (700-1000 tokens)
    private let targetTokenCount = 850
    private let minTokenCount = 700
    private let maxTokenCount = 1000

    /// Rough heuristic: 1 token ≈ 4 characters (for English text)
    private let charsPerToken = 4

    // MARK: - Public API

    /// Chunk a journal entry into semantic segments
    /// - Parameters:
    ///   - entry: The journal entry to chunk
    ///   - content: The full text content of the entry
    /// - Returns: Array of journal chunks with metadata (embeddings not yet generated)
    func chunkEntry(entry: HumanEntry, content: String) throws -> [JournalChunk] {
        guard !content.isEmpty else {
            return []
        }

        // Parse date from entry
        let entryDate = parseEntryDate(entry: entry)

        // Split into paragraphs first
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

            // If adding this paragraph would exceed max tokens, finalize current chunk
            if currentTokens + paragraphTokens > maxTokenCount && !currentChunk.isEmpty {
                let chunk = createChunk(
                    text: currentChunk,
                    entryId: entry.id,
                    startChar: currentStartChar,
                    endChar: currentCharPosition,
                    date: entryDate
                )
                chunks.append(chunk)

                // Start new chunk
                currentChunk = paragraph
                currentStartChar = currentCharPosition
            } else {
                // Add paragraph to current chunk
                if !currentChunk.isEmpty {
                    currentChunk += "\n\n"
                    currentCharPosition += 2
                }
                currentChunk += paragraph
            }

            currentCharPosition += paragraph.count + 2 // +2 for paragraph separator

            // If current chunk is at target size, finalize it
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

        // Add remaining text as final chunk
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

        // If content was very short and resulted in no chunks, create one chunk
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

    /// Estimate token count using character count heuristic
    /// Note: This is approximate. OpenAI tokenizers are more complex, but this is sufficient for chunking
    private func estimateTokenCount(_ text: String) -> Int {
        return text.count / charsPerToken
    }

    /// Create a JournalChunk from text and metadata
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
            embedding: nil, // Will be populated later by embedding service
            startChar: startChar,
            endChar: endChar,
            date: date,
            tokenCount: tokenCount
        )
    }

    /// Parse Date object from HumanEntry
    /// Tries to extract date from filename, falls back to current date
    private func parseEntryDate(entry: HumanEntry) -> Date {
        // Filename format: [UUID]-[yyyy-MM-dd-HH-mm-ss].md
        let filename = entry.filename

        // Extract date string between brackets
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

        // Fallback to current date
        return Date()
    }
}
