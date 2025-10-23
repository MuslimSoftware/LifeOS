import Foundation

/// Metric types that can be tracked over time
enum TimeSeriesMetric: String, Codable, CaseIterable {
    case happiness
    case stress
    case energy
}

/// A single data point in a time series
struct TimeSeriesDataPoint: Codable, Identifiable {
    let id: UUID
    let date: Date
    let metric: TimeSeriesMetric
    let value: Double
    let confidence: Double

    init(
        id: UUID = UUID(),
        date: Date,
        metric: TimeSeriesMetric,
        value: Double,
        confidence: Double
    ) {
        self.id = id
        self.date = date
        self.metric = metric
        self.value = value
        self.confidence = confidence
    }
}
