import Foundation
import GRDB

struct StickyNote: Identifiable, Codable {
    let id: UUID
    var date: Date
    var content: String
    var createdAt: Date
    var updatedAt: Date
}

extension StickyNote: FetchableRecord, PersistableRecord {
    static let databaseTableName = "sticky_notes"

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
