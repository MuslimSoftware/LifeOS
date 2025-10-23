import Foundation

/// Represents the direction of a trend over time
enum Trend: String, Codable {
    case up = "up"
    case down = "down"
    case stable = "stable"

    /// Initialize from a comparison of two values
    /// - Parameters:
    ///   - current: The current value
    ///   - previous: The previous value
    ///   - threshold: The minimum change required to be considered up/down (default: 5.0)
    init(current: Double, previous: Double, threshold: Double = 5.0) {
        let change = current - previous
        if change > threshold {
            self = .up
        } else if change < -threshold {
            self = .down
        } else {
            self = .stable
        }
    }

    /// User-friendly description
    var description: String {
        switch self {
        case .up: return "improving"
        case .down: return "declining"
        case .stable: return "stable"
        }
    }

    /// Emoji representation
    var emoji: String {
        switch self {
        case .up: return "↗️"
        case .down: return "↘️"
        case .stable: return "→"
        }
    }
}
