import Foundation
import GRDB

class StickyNoteRepository {
    private let dbService: DatabaseService

    init(dbService: DatabaseService = .shared) {
        self.dbService = dbService
    }

    func save(_ note: StickyNote) throws {
        try dbService.getQueue().write { db in
            var mutableNote = note
            mutableNote.updatedAt = Date()
            try mutableNote.save(db)
        }
    }

    func saveBatch(_ notes: [StickyNote]) throws {
        try dbService.getQueue().write { db in
            for note in notes {
                try note.save(db)
            }
        }
    }

    func getStickyNote(forDate date: Date) throws -> StickyNote? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try dbService.getQueue().read { db in
            try StickyNote
                .filter(Column("date") >= startOfDay && Column("date") < endOfDay)
                .fetchOne(db)
        }
    }


    func delete(id: UUID) throws {
        try dbService.getQueue().write { db in
            _ = try StickyNote.deleteOne(db, key: id.uuidString)
        }
    }
}
