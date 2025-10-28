import Foundation

/// Represents a reference to a specific portion of a journal entry
/// Used for provenance tracking - linking analytics back to original text
struct SourceSpan: Codable, Hashable {
    let entryId: UUID
    let startChar: Int
    let endChar: Int

    init(entryId: UUID, startChar: Int, endChar: Int) {
        self.entryId = entryId
        self.startChar = startChar
        self.endChar = endChar
    }
}
