import Foundation

/// An event detected in journal text
struct DetectedEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let date: Date?
    let description: String
    let sentiment: Double  // -1 (negative) to 1 (positive)

    init(
        id: UUID = UUID(),
        title: String,
        date: Date? = nil,
        description: String,
        sentiment: Double
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.description = description
        self.sentiment = sentiment
    }
}
