import Foundation
import GRDB

struct TODOItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var date: Date
    var text: String
    var completed: Bool
    var createdAt: Date
    var dueTime: Date?

    init(id: UUID = UUID(), date: Date, text: String, completed: Bool, createdAt: Date = Date(), dueTime: Date? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.completed = completed
        self.createdAt = createdAt
        self.dueTime = dueTime
    }
}

extension TODOItem: FetchableRecord, PersistableRecord {
    static let databaseTableName = "todos"

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case text
        case completed
        case createdAt = "created_at"
        case dueTime = "due_time"
    }
}
