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

    // MARK: - Private Helpers

    private func rowToChunk(_ row: Row) throws -> JournalChunk {
        guard let id = UUID(uuidString: row["id"]),
              let entryId = UUID(uuidString: row["entry_id"]) else {
            throw DatabaseError.queryFailed("Invalid UUID in chunk row")
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
        _ = data.withUnsafeMutableBytes { buffer in
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
