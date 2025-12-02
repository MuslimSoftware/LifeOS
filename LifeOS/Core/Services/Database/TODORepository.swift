import Foundation
import GRDB

class TODORepository {
    private let dbService: DatabaseService

    init(dbService: DatabaseService = .shared) {
        self.dbService = dbService
    }

    func save(_ todo: TODOItem) throws {
        try dbService.getQueue().write { db in
            try todo.save(db)
        }
    }

    func saveBatch(_ todos: [TODOItem]) throws {
        try dbService.getQueue().write { db in
            for todo in todos {
                try todo.save(db)
            }
        }
    }

    func getTODOs(forDate date: Date) throws -> [TODOItem] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try dbService.getQueue().read { db in
            try TODOItem
                .filter(Column("date") >= startOfDay && Column("date") < endOfDay)
                .order(Column("created_at").asc)
                .fetchAll(db)
        }
    }

    func getAllTODOs() throws -> [TODOItem] {
        try dbService.getQueue().read { db in
            try TODOItem
                .order(Column("created_at").desc)
                .fetchAll(db)
        }
    }

    func getIncompleteTODOs() throws -> [TODOItem] {
        try dbService.getQueue().read { db in
            try TODOItem
                .filter(Column("completed") == false)
                .order(Column("created_at").asc)
                .fetchAll(db)
        }
    }

    func delete(id: UUID) throws {
        try dbService.getQueue().write { db in
            _ = try TODOItem.deleteOne(db, key: id)
        }
    }

    func deleteAll(forDate date: Date) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        try dbService.getQueue().write { db in
            _ = try TODOItem
                .filter(Column("date") >= startOfDay && Column("date") < endOfDay)
                .deleteAll(db)
        }
    }
}
