import Foundation

/// Aggregated analytics for a calendar month
struct MonthSummary: Codable, Identifiable {
    let id: UUID
    let year: Int
    let month: Int

    let summaryText: String
    let keyTopics: [String]

    // Happiness metrics
    let happinessAvg: Double
    let happinessConfidenceInterval: (lower: Double, upper: Double)

    // Drivers of happiness
    let driversPositive: [String]
    let driversNegative: [String]

    // Notable events
    let topEvents: [DetectedEvent]

    // Provenance
    let sourceSpans: [SourceSpan]

    // Metadata
    let generatedAt: Date

    init(
        id: UUID = UUID(),
        year: Int,
        month: Int,
        summaryText: String,
        keyTopics: [String] = [],
        happinessAvg: Double,
        happinessConfidenceInterval: (Double, Double),
        driversPositive: [String] = [],
        driversNegative: [String] = [],
        topEvents: [DetectedEvent] = [],
        sourceSpans: [SourceSpan] = [],
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.year = year
        self.month = month
        self.summaryText = summaryText
        self.keyTopics = keyTopics
        self.happinessAvg = happinessAvg
        self.happinessConfidenceInterval = happinessConfidenceInterval
        self.driversPositive = driversPositive
        self.driversNegative = driversNegative
        self.topEvents = topEvents
        self.sourceSpans = sourceSpans
        self.generatedAt = generatedAt
    }

    var dateComponents: DateComponents {
        DateComponents(year: year, month: month)
    }
}

// Custom Codable implementation for tuple
extension MonthSummary {
    enum CodingKeys: String, CodingKey {
        case id, year, month, summaryText, keyTopics
        case happinessAvg, happinessCI_lower, happinessCI_upper
        case driversPositive, driversNegative, topEvents, sourceSpans
        case generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        year = try container.decode(Int.self, forKey: .year)
        month = try container.decode(Int.self, forKey: .month)
        summaryText = try container.decode(String.self, forKey: .summaryText)
        keyTopics = try container.decode([String].self, forKey: .keyTopics)
        happinessAvg = try container.decode(Double.self, forKey: .happinessAvg)
        let lower = try container.decode(Double.self, forKey: .happinessCI_lower)
        let upper = try container.decode(Double.self, forKey: .happinessCI_upper)
        happinessConfidenceInterval = (lower, upper)
        driversPositive = try container.decode([String].self, forKey: .driversPositive)
        driversNegative = try container.decode([String].self, forKey: .driversNegative)
        topEvents = try container.decode([DetectedEvent].self, forKey: .topEvents)
        sourceSpans = try container.decode([SourceSpan].self, forKey: .sourceSpans)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(year, forKey: .year)
        try container.encode(month, forKey: .month)
        try container.encode(summaryText, forKey: .summaryText)
        try container.encode(keyTopics, forKey: .keyTopics)
        try container.encode(happinessAvg, forKey: .happinessAvg)
        try container.encode(happinessConfidenceInterval.lower, forKey: .happinessCI_lower)
        try container.encode(happinessConfidenceInterval.upper, forKey: .happinessCI_upper)
        try container.encode(driversPositive, forKey: .driversPositive)
        try container.encode(driversNegative, forKey: .driversNegative)
        try container.encode(topEvents, forKey: .topEvents)
        try container.encode(sourceSpans, forKey: .sourceSpans)
        try container.encode(generatedAt, forKey: .generatedAt)
    }
}
