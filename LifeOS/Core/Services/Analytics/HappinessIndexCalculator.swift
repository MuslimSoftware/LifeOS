import Foundation

/// Service for computing happiness scores and aggregating analytics across time periods
/// Implements the happiness formula and statistical methods for robust aggregation
class HappinessIndexCalculator {

    // MARK: - Happiness Formula

    /// Compute happiness score using the defined formula
    /// Formula: h = 50 + 30*valence + 10*gratitude + 8*positive_event_density
    ///              - 12*anxiety - 10*rumination - 8*conflict
    ///
    /// - Parameters:
    ///   - valence: Emotional valence (-1 to 1)
    ///   - emotions: Emotion scores
    ///   - positiveEventDensity: Density of positive events (0-1)
    /// - Returns: Happiness score (0-100)
    func computeHappinessScore(
        valence: Double,
        emotions: EmotionScores,
        positiveEventDensity: Double = 0.0
    ) -> Double {
        // Base happiness
        var happiness = 50.0

        // Positive contributions
        happiness += 30.0 * valence
        happiness += 10.0 * emotions.gratitude
        happiness += 8.0 * positiveEventDensity

        // Negative contributions
        happiness -= 12.0 * emotions.anxiety
        happiness -= 10.0 * emotions.sadness  // Using sadness as proxy for rumination
        happiness -= 8.0 * emotions.anger     // Using anger as proxy for conflict

        // Clamp to 0-100 range
        return max(0.0, min(100.0, happiness))
    }

    // MARK: - Monthly Aggregates

    /// Compute monthly happiness statistics with confidence intervals
    /// Uses robust methods to filter outliers
    /// - Parameter entries: All entry analytics for the month
    /// - Returns: Tuple of (average, confidence interval)
    func computeMonthlyAggregates(entries: [EntryAnalytics]) -> (avg: Double, ci: (Double, Double)) {
        guard !entries.isEmpty else {
            return (0.0, (0.0, 0.0))
        }

        let scores = entries.map { $0.happinessScore }

        // Filter outliers using IQR method
        let filtered = filterOutliers(scores)

        // Compute mean
        let mean = filtered.reduce(0.0, +) / Double(max(filtered.count, 1))

        // Compute 95% confidence interval
        let ci = confidenceInterval(values: filtered, confidence: 0.95)

        return (mean, ci)
    }

    /// Filter outliers using Interquartile Range (IQR) method
    /// Removes values beyond 1.5 * IQR from Q1/Q3
    private func filterOutliers(_ values: [Double]) -> [Double] {
        guard values.count > 3 else { return values }

        let sorted = values.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4

        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1

        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr

        return sorted.filter { $0 >= lowerBound && $0 <= upperBound }
    }

    /// Calculate confidence interval for a set of values
    /// Uses t-distribution for small sample sizes
    private func confidenceInterval(values: [Double], confidence: Double) -> (Double, Double) {
        guard values.count > 1 else {
            let value = values.first ?? 0.0
            return (value, value)
        }

        let mean = values.reduce(0.0, +) / Double(values.count)

        // Calculate standard deviation
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0.0, +) / Double(values.count - 1)
        let stdDev = sqrt(variance)

        // Standard error
        let standardError = stdDev / sqrt(Double(values.count))

        // t-value for 95% confidence (approximation for simplicity)
        // For large samples (n > 30), t ≈ 1.96
        // For small samples, use conservative estimate of 2.0
        let tValue: Double = values.count > 30 ? 1.96 : 2.0

        let margin = tValue * standardError

        return (mean - margin, mean + margin)
    }

    // MARK: - Time Series

    /// Generate time series data points for a date range
    /// Queries database and computes daily/weekly aggregates
    /// - Parameters:
    ///   - from: Start date
    ///   - to: End date
    ///   - repository: Analytics repository to query
    /// - Returns: Array of time series data points
    func computeTimeSeriesDataPoints(
        from startDate: Date,
        to endDate: Date,
        repository: EntryAnalyticsRepository
    ) async throws -> [TimeSeriesDataPoint] {
        // Load all analytics in date range
        let allAnalytics = try repository.getAnalytics(from: startDate, to: endDate)

        guard !allAnalytics.isEmpty else {
            return []
        }

        // Group by day
        let calendar = Calendar.current
        var dailyGroups: [Date: [EntryAnalytics]] = [:]

        for analytics in allAnalytics {
            let dayStart = calendar.startOfDay(for: analytics.date)
            dailyGroups[dayStart, default: []].append(analytics)
        }

        // Create data points for each day
        var dataPoints: [TimeSeriesDataPoint] = []

        for (date, entries) in dailyGroups.sorted(by: { $0.key < $1.key }) {
            // Compute average happiness for the day
            let scores = entries.map { $0.happinessScore }
            let avgHappiness = scores.reduce(0.0, +) / Double(scores.count)

            // Compute confidence (average of entry confidences)
            let avgConfidence = entries.map { $0.confidence }.reduce(0.0, +) / Double(entries.count)

            let dataPoint = TimeSeriesDataPoint(
                date: date,
                metric: .happiness,
                value: avgHappiness,
                confidence: avgConfidence
            )

            dataPoints.append(dataPoint)
        }

        // Optionally: compute stress and energy metrics
        // For now, focusing on happiness

        return dataPoints
    }

    /// Compute stress metric from analytics
    /// Stress correlates with anxiety and negative emotions
    func computeStressScore(analytics: EntryAnalytics) -> Double {
        let emotions = analytics.emotions

        // Stress formula: weighted combination of anxiety, anger, sadness
        let stress = (
            50.0 * emotions.anxiety +
            30.0 * emotions.anger +
            20.0 * emotions.sadness
        )

        // Scale to 0-100
        return max(0.0, min(100.0, stress * 100.0))
    }

    /// Compute energy metric from analytics
    /// Energy correlates with arousal and positive emotions
    func computeEnergyScore(analytics: EntryAnalytics) -> Double {
        let arousal = analytics.arousal
        let joy = analytics.emotions.joy

        // Energy formula: combination of arousal and joy
        let energy = (60.0 * arousal + 40.0 * joy)

        // Scale to 0-100
        return max(0.0, min(100.0, energy * 100.0))
    }
}
