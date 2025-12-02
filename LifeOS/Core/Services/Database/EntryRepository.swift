import Foundation
import GRDB

class EntryRepository {
    private let dbService: DatabaseService

    init(dbService: DatabaseService = .shared) {
        self.dbService = dbService
    }

    func save(_ entry: HumanEntry) throws {
        try dbService.getQueue().write { db in
            var mutableEntry = entry
            mutableEntry.updatedAt = Date()
            try mutableEntry.save(db)
        }
    }

    func saveBatch(_ entries: [HumanEntry]) throws {
        try dbService.getQueue().write { db in
            for var entry in entries {
                entry.updatedAt = Date()
                try entry.save(db)
            }
        }
    }

    /// Save a batch of entries while preserving their timestamps (for imports)
    func saveImportedBatch(_ entries: [HumanEntry]) throws {
        try dbService.getQueue().write { db in
            for entry in entries {
                try entry.save(db)
            }
        }
    }

    func getEntry(id: UUID) throws -> HumanEntry? {
        try dbService.getQueue().read { db in
            try HumanEntry.fetchOne(db, key: id.uuidString)
        }
    }

    func getAllEntries() throws -> [HumanEntry] {
        try dbService.getQueue().read { db in
            try HumanEntry
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    func getEntries(year: Int) throws -> [HumanEntry] {
        try dbService.getQueue().read { db in
            try HumanEntry
                .filter(Column("year") == year)
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    func getEntries(from: Date, to: Date) throws -> [HumanEntry] {
        try dbService.getQueue().read { db in
            try HumanEntry
                .filter(Column("created_at") >= from && Column("created_at") <= to)
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    func getEntry(forDate date: Date) throws -> HumanEntry? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try dbService.getQueue().read { db in
            try HumanEntry
                .filter(Column("created_at") >= startOfDay && Column("created_at") < endOfDay)
                .fetchOne(db)
        }
    }

    func delete(id: UUID) throws {
        try dbService.getQueue().write { db in
            _ = try HumanEntry.deleteOne(db, key: id.uuidString)
        }
    }

    func deleteAll() throws {
        try dbService.getQueue().write { db in
            _ = try HumanEntry.deleteAll(db)
        }
    }

    func searchEntries(query: String) throws -> [HumanEntry] {
        try dbService.getQueue().read { db in
            let pattern = FTS5Pattern(matchingAllTokensIn: query)
            let ids = try Row.fetchAll(db, sql: """
                SELECT rowid FROM journal_entries_fts WHERE journal_entries_fts MATCH ?
                """, arguments: [pattern])

            let rowids = ids.map { $0[0] as Int64 }
            return try HumanEntry
                .filter(rowids.contains(Column.rowID))
                .fetchAll(db)
        }
    }
}
