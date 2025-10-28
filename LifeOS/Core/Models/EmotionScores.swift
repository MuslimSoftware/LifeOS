import Foundation

/// Emotional state extracted from journal text
/// Values normalized to [0, 1] range
struct EmotionScores: Codable, Equatable {
    let joy: Double
    let sadness: Double
    let anger: Double
    let anxiety: Double
    let gratitude: Double

    init(joy: Double, sadness: Double, anger: Double, anxiety: Double, gratitude: Double) {
        self.joy = joy
        self.sadness = sadness
        self.anger = anger
        self.anxiety = anxiety
        self.gratitude = gratitude
    }

    static var neutral: EmotionScores {
        EmotionScores(joy: 0.5, sadness: 0.5, anger: 0.5, anxiety: 0.5, gratitude: 0.5)
    }
}
