import Foundation
import GRDB

/// Repository for CRUD operations on JournalChunk records
class ChunkRepository {
    private let dbService: DatabaseService

    init(dbService: DatabaseService = .shared) {
        self.dbService = dbService
    }

    /// Save a chunk to the database
    func save(_ chunk: JournalChunk) throws {
        try dbService.getQueue().write { db in
            let embeddingData = chunk.embedding.map { floatArrayToData($0) }

            try db.execute(
                sql: """
                INSERT INTO chunks (id, entry_id, text, embedding, start_char, end_char, date, token_count, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    embedding = excluded.embedding,
                    text = excluded.text
                """,
                arguments: [
                    chunk.id.uuidString,
                    chunk.entryId.uuidString,
                    chunk.text,
                    embeddingData,
                    chunk.startChar,
                    chunk.endChar,
                    chunk.date,
                    chunk.tokenCount,
                    Date()
                ]
            )
        }
    }

    /// Save multiple chunks in a transaction
    func saveBatch(_ chunks: [JournalChunk]) throws {
        try dbService.getQueue().write { db in
            for chunk in chunks {
                let embeddingData = chunk.embedding.map { floatArrayToData($0) }

                try db.execute(
                    sql: """
                    INSERT INTO chunks (id, entry_id, text, embedding, start_char, end_char, date, token_count, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        embedding = excluded.embedding,
                        text = excluded.text
                    """,
                    arguments: [
                        chunk.id.uuidString,
                        chunk.entryId.uuidString,
                        chunk.text,
                        embeddingData,
                        chunk.startChar,
                        chunk.endChar,
                        chunk.date,
                        chunk.tokenCount,
                        Date()
                    ]
                )
            }
        }
    }

    /// Get all chunks for a specific entry
    func getChunks(forEntryId entryId: UUID) throws -> [JournalChunk] {
        try dbService.getQueue().read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM chunks WHERE entry_id = ? ORDER BY start_char",
                arguments: [entryId.uuidString]
            )
            return try rows.map { try rowToChunk($0) }
        }
    }

    /// Get chunks within a date range
    func getChunks(from startDate: Date, to endDate: Date) throws -> [JournalChunk] {
        try dbService.getQueue().read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM chunks WHERE date BETWEEN ? AND ? ORDER BY date",
                arguments: [startDate, endDate]
            )
            return try rows.map { try rowToChunk($0) }
        }
    }

    /// Get all chunks (for full-text search or reprocessing)
    func getAllChunks() throws -> [JournalChunk] {
        try dbService.getQueue().read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM chunks ORDER BY date DESC")
            return try rows.map { try rowToChunk($0) }
        }
    }

    /// Delete all chunks for a specific entry
    func deleteChunks(forEntryId entryId: UUID) throws {
        try dbService.getQueue().write { db in
            try db.execute(
                sql: "DELETE FROM chunks WHERE entry_id = ?",
                arguments: [entryId.uuidString]
            )
        }
    }

    /// Check if chunks exist for a specific entry
    /// - Parameter entryId: The entry UUID to check
    /// - Returns: True if at least one chunk exists for the entry
    func hasChunksForEntry(entryId: UUID) throws -> Bool {
        try dbService.getQueue().read { db in
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM chunks WHERE entry_id = ?",
                arguments: [entryId.uuidString]
            )
            return (count ?? 0) > 0
        }
    }

    /// Delete all chunks from the database
    func deleteAll() throws {
        let queue = try dbService.getQueue()

        // Delete operations inside transaction
        try queue.write { db in
            try db.execute(sql: "DELETE FROM chunks")
            try db.execute(sql: "DELETE FROM chunks_fts")
        }

        // VACUUM must run outside transaction
        try queue.inDatabase { db in
            try db.execute(sql: "VACUUM")
        }

        print("✅ Successfully cleared all embeddings and compacted database")
    }

    /// Clean up chunks for entries with empty journal sections
    /// Returns the number of entry IDs that had chunks deleted
    func deleteChunksForEmptyJournalEntries(validEntryIds: Set<UUID>) throws -> Int {
        // Get all unique entry IDs in the database
        let allChunks = try getAllChunks()
        let dbEntryIds = Set(allChunks.map { $0.entryId })

        // Find entry IDs in DB that are not in the valid entries list
        // These are entries that either don't exist or have empty journal sections
        let emptyJournalEntryIds = dbEntryIds.subtracting(validEntryIds)

        if emptyJournalEntryIds.isEmpty {
            print("✅ No chunks found for empty journal entries")
            return 0
        }

        print("🗑️ Found \(emptyJournalEntryIds.count) entries with empty journal sections in database")

        // Delete chunks for each empty journal entry
        var deletedCount = 0
        for entryId in emptyJournalEntryIds {
            do {
                try deleteChunks(forEntryId: entryId)
                deletedCount += 1
                print("   Deleted chunks for entry: \(entryId)")
            } catch {
                print("   ⚠️ Failed to delete chunks for entry \(entryId): \(error)")
            }
        }

        print("✅ Cleaned up chunks for \(deletedCount) entries with empty journal sections")
        return deletedCount
    }

    // MARK: - Private Helpers

    private func rowToChunk(_ row: Row) throws -> JournalChunk {
        guard let id = UUID(uuidString: row["id"]),
              let entryId = UUID(uuidString: row["entry_id"]) else {
            throw LifeOSDatabaseError.queryFailed("Invalid UUID in chunk row")
        }

        let embeddingData: Data? = row["embedding"]
        let embedding = embeddingData.map { dataToFloatArray($0) }

        return JournalChunk(
            id: id,
            entryId: entryId,
            text: row["text"],
            embedding: embedding,
            startChar: row["start_char"],
            endChar: row["end_char"],
            date: row["date"],
            tokenCount: row["token_count"]
        )
    }

    private func floatArrayToData(_ floats: [Float]) -> Data {
        var data = Data(count: floats.count * MemoryLayout<Float>.size)
        data.withUnsafeMutableBytes { buffer in
            floats.withUnsafeBytes { floatBuffer in
                buffer.copyMemory(from: floatBuffer)
            }
        }
        return data
    }

    private func dataToFloatArray(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        var floats = [Float](repeating: 0, count: count)
        _ = floats.withUnsafeMutableBytes { buffer in
            data.copyBytes(to: buffer)
        }
        return floats
    }
}
