import Foundation
import GRDB

struct HumanEntry: Identifiable, Codable {
    let id: UUID
    var date: String
    var year: Int
    var journalText: String
    var previewText: String
    var encryptedData: Data?
    var createdAt: Date
    var updatedAt: Date

    var filename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let timestamp = formatter.string(from: createdAt)
        return "[\(id.uuidString)]-[\(timestamp)].md"
    }

    init(id: UUID, date: String, year: Int, journalText: String, previewText: String, encryptedData: Data?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.date = date
        self.year = year
        self.journalText = journalText
        self.previewText = previewText
        self.encryptedData = encryptedData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func createNew() -> HumanEntry {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        return HumanEntry(
            id: UUID(),
            date: formatter.string(from: now),
            year: Calendar.current.component(.year, from: now),
            journalText: "",
            previewText: "",
            encryptedData: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    static func createWithDate(date: Date) -> HumanEntry {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        return HumanEntry(
            id: UUID(),
            date: formatter.string(from: date),
            year: Calendar.current.component(.year, from: date),
            journalText: "",
            previewText: "",
            encryptedData: nil,
            createdAt: date,
            updatedAt: date
        )
    }

    @available(*, deprecated, message: "Legacy constructor for FileManagerService compatibility")
    init(id: UUID, date: String, year: Int, journalText: String, previewText: String, createdAt: Date, updatedAt: Date) {
        self.init(
            id: id,
            date: date,
            year: year,
            journalText: journalText,
            previewText: previewText,
            encryptedData: nil,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension HumanEntry: FetchableRecord, PersistableRecord {
    static let databaseTableName = "journal_entries"

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case year
        case journalText = "journal_text"
        case previewText = "preview_text"
        case encryptedData = "encrypted_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
