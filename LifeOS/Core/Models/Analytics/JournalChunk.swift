import Foundation

/// Represents a segment of journal text with its embedding vector
/// Used for semantic search and retrieval
struct JournalChunk: Identifiable, Codable {
    let id: UUID
    let entryId: UUID
    let text: String
    let embedding: [Float]?  // Vector from OpenAI embeddings API
    let startChar: Int
    let endChar: Int
    let date: Date
    let tokenCount: Int

    init(
        id: UUID = UUID(),
        entryId: UUID,
        text: String,
        embedding: [Float]? = nil,
        startChar: Int,
        endChar: Int,
        date: Date,
        tokenCount: Int
    ) {
        self.id = id
        self.entryId = entryId
        self.text = text
        self.embedding = embedding
        self.startChar = startChar
        self.endChar = endChar
        self.date = date
        self.tokenCount = tokenCount
    }

    var sourceSpan: SourceSpan {
        SourceSpan(entryId: entryId, startChar: startChar, endChar: endChar)
    }
}
