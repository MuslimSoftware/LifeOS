import Foundation

/// Analytics computed for a single journal entry
struct EntryAnalytics: Codable, Identifiable {
    let id: UUID
    let entryId: UUID
    let date: Date

    // Happiness metrics
    let happinessScore: Double  // 0-100 scale
    let valence: Double         // -1 to 1 (negative to positive)
    let arousal: Double         // 0 to 1 (calm to excited)

    // Emotional profile
    let emotions: EmotionScores

    // Detected events
    let events: [DetectedEvent]

    // Confidence in analysis
    let confidence: Double  // 0-1

    // Metadata
    let analyzedAt: Date

    init(
        id: UUID = UUID(),
        entryId: UUID,
        date: Date,
        happinessScore: Double,
        valence: Double,
        arousal: Double,
        emotions: EmotionScores,
        events: [DetectedEvent] = [],
        confidence: Double,
        analyzedAt: Date = Date()
    ) {
        self.id = id
        self.entryId = entryId
        self.date = date
        self.happinessScore = happinessScore
        self.valence = valence
        self.arousal = arousal
        self.emotions = emotions
        self.events = events
        self.confidence = confidence
        self.analyzedAt = analyzedAt
    }
}
