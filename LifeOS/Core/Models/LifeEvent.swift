import Foundation

/// A significant life event extracted from journal entries
struct LifeEvent: Codable, Identifiable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date?
    let description: String
    let categories: [String]
    let salience: Double  // 0-1, how important/significant
    let sentiment: Double  // -1 to 1
    let sourceSpans: [SourceSpan]

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        description: String,
        categories: [String] = [],
        salience: Double,
        sentiment: Double,
        sourceSpans: [SourceSpan] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.description = description
        self.categories = categories
        self.salience = salience
        self.sentiment = sentiment
        self.sourceSpans = sourceSpans
    }

    var duration: TimeInterval? {
        guard let end = endDate else { return nil }
        return end.timeIntervalSince(startDate)
    }

    var isOngoing: Bool {
        endDate == nil
    }
}
