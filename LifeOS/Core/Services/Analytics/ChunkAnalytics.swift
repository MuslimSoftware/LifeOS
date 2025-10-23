import Foundation

/// Temporary structure for analytics extracted from a single chunk
/// This gets aggregated into EntryAnalytics for the full entry
struct ChunkAnalytics: Codable {
    /// Happiness score 0-100
    let happiness: Double

    /// Valence (emotional positivity): -1 (very negative) to 1 (very positive)
    let valence: Double

    /// Arousal (emotional activation): 0 (calm) to 1 (excited/activated)
    let arousal: Double

    /// Detailed emotion scores
    let joy: Double        // 0-1
    let sadness: Double    // 0-1
    let anger: Double      // 0-1
    let anxiety: Double    // 0-1
    let gratitude: Double  // 0-1

    /// Events detected in this chunk
    let events: [EventExtraction]

    /// Confidence in the analysis (0-1)
    let confidence: Double

    /// Convert emotion fields to EmotionScores model
    var emotionScores: EmotionScores {
        EmotionScores(
            joy: joy,
            sadness: sadness,
            anger: anger,
            anxiety: anxiety,
            gratitude: gratitude
        )
    }
}

/// Event extracted from chunk text (temporary structure)
struct EventExtraction: Codable {
    let title: String
    let description: String?
    let sentiment: String  // "positive", "negative", or "neutral"
}
