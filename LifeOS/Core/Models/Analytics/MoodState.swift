import Foundation

/// Represents the current mood state with metrics and trends
struct MoodState: Codable {
    /// Current happiness score (0-100)
    let happiness: Double

    /// Current stress score (0-100)
    let stress: Double

    /// Current energy score (0-100)
    let energy: Double

    /// Trend direction for happiness (comparing recent vs previous period)
    let happinessTrend: Trend

    /// Trend direction for stress
    let stressTrend: Trend

    /// Trend direction for energy
    let energyTrend: Trend

    /// Initialize with individual values and trends
    init(
        happiness: Double,
        stress: Double,
        energy: Double,
        happinessTrend: Trend,
        stressTrend: Trend,
        energyTrend: Trend
    ) {
        self.happiness = happiness
        self.stress = stress
        self.energy = energy
        self.happinessTrend = happinessTrend
        self.stressTrend = stressTrend
        self.energyTrend = energyTrend
    }

    /// Summary description of the mood state
    var summary: String {
        var parts: [String] = []

        // Happiness
        let happinessLevel = happiness > 70 ? "high" : happiness > 40 ? "moderate" : "low"
        parts.append("Happiness is \(happinessLevel) and \(happinessTrend.description)")

        // Stress
        let stressLevel = stress > 70 ? "high" : stress > 40 ? "moderate" : "low"
        parts.append("stress is \(stressLevel) and \(stressTrend.description)")

        // Energy
        let energyLevel = energy > 70 ? "high" : energy > 40 ? "moderate" : "low"
        parts.append("energy is \(energyLevel) and \(energyTrend.description)")

        return parts.joined(separator: ", ")
    }
}
