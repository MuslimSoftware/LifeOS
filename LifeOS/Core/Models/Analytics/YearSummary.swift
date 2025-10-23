import Foundation

/// Aggregated analytics for a calendar year
struct YearSummary: Codable, Identifiable {
    let id: UUID
    let year: Int

    let summaryText: String

    // Happiness metrics
    let happinessAvg: Double
    let happinessConfidenceInterval: (lower: Double, upper: Double)

    // Major events
    let topEvents: [DetectedEvent]

    // Provenance
    let sourceSpans: [SourceSpan]

    // Metadata
    let generatedAt: Date

    init(
        id: UUID = UUID(),
        year: Int,
        summaryText: String,
        happinessAvg: Double,
        happinessConfidenceInterval: (Double, Double),
        topEvents: [DetectedEvent] = [],
        sourceSpans: [SourceSpan] = [],
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.year = year
        self.summaryText = summaryText
        self.happinessAvg = happinessAvg
        self.happinessConfidenceInterval = happinessConfidenceInterval
        self.topEvents = topEvents
        self.sourceSpans = sourceSpans
        self.generatedAt = generatedAt
    }
}

// Custom Codable implementation for tuple
extension YearSummary {
    enum CodingKeys: String, CodingKey {
        case id, year, summaryText
        case happinessAvg, happinessCI_lower, happinessCI_upper
        case topEvents, sourceSpans, generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        year = try container.decode(Int.self, forKey: .year)
        summaryText = try container.decode(String.self, forKey: .summaryText)
        happinessAvg = try container.decode(Double.self, forKey: .happinessAvg)
        let lower = try container.decode(Double.self, forKey: .happinessCI_lower)
        let upper = try container.decode(Double.self, forKey: .happinessCI_upper)
        happinessConfidenceInterval = (lower, upper)
        topEvents = try container.decode([DetectedEvent].self, forKey: .topEvents)
        sourceSpans = try container.decode([SourceSpan].self, forKey: .sourceSpans)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(year, forKey: .year)
        try container.encode(summaryText, forKey: .summaryText)
        try container.encode(happinessAvg, forKey: .happinessAvg)
        try container.encode(happinessConfidenceInterval.lower, forKey: .happinessCI_lower)
        try container.encode(happinessConfidenceInterval.upper, forKey: .happinessCI_upper)
        try container.encode(topEvents, forKey: .topEvents)
        try container.encode(sourceSpans, forKey: .sourceSpans)
        try container.encode(generatedAt, forKey: .generatedAt)
    }
}
