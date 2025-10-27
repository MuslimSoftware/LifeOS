import Foundation

/// Metadata about retrieve results including confidence, coverage, and gaps
struct RetrieveMetadata: Codable {
    let count: Int
    let dateRange: DateRange?
    let similarityStats: SimilarityStats?
    let confidence: Confidence
    let gaps: [DataGap]

    struct DateRange: Codable {
        let start: Date
        let end: Date
        let spanDays: Int

        init(start: Date, end: Date) {
            self.start = start
            self.end = end
            self.spanDays = Int(end.timeIntervalSince(start) / 86400)
        }

        init?(dates: [Date]) {
            guard let start = dates.min(), let end = dates.max() else {
                return nil
            }
            self.init(start: start, end: end)
        }
    }

    struct SimilarityStats: Codable {
        let median: Double
        let iqr: (lower: Double, upper: Double)
        let min: Double
        let max: Double

        init(similarities: [Double]) {
            let sorted = similarities.sorted()
            self.median = sorted.median() ?? 0
            self.iqr = sorted.iqr()
            self.min = sorted.first ?? 0
            self.max = sorted.last ?? 0
        }

        enum CodingKeys: String, CodingKey {
            case median, iqr, min, max
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(median, forKey: .median)
            try container.encode([iqr.lower, iqr.upper], forKey: .iqr)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            median = try container.decode(Double.self, forKey: .median)
            let iqrArray = try container.decode([Double].self, forKey: .iqr)
            iqr = (iqrArray[0], iqrArray[1])
            min = try container.decode(Double.self, forKey: .min)
            max = try container.decode(Double.self, forKey: .max)
        }
    }

    enum Confidence: String, Codable {
        case high
        case medium
        case low

        /// Compute confidence based on result count, similarity, and date coverage
        static func compute(
            count: Int,
            medianSimilarity: Double?,
            dateSpan: Int?
        ) -> Confidence {
            // High confidence: ≥50 items, good similarity (≥0.6), full coverage
            if count >= 50,
               let sim = medianSimilarity, sim >= 0.6,
               let span = dateSpan, span > 0 {
                return .high
            }

            // Medium confidence: ≥10 items, decent similarity (≥0.4)
            if count >= 10,
               medianSimilarity ?? 0 >= 0.4 {
                return .medium
            }

            // Low confidence: everything else
            return .low
        }
    }

    struct DataGap: Codable {
        let start: Date
        let end: Date
        let reason: String
        let spanDays: Int

        init(start: Date, end: Date, reason: String = "No entries in this period") {
            self.start = start
            self.end = end
            self.reason = reason
            self.spanDays = Int(end.timeIntervalSince(start) / 86400)
        }
    }

    init(
        count: Int,
        dateRange: DateRange?,
        similarityStats: SimilarityStats?,
        confidence: Confidence,
        gaps: [DataGap] = []
    ) {
        self.count = count
        self.dateRange = dateRange
        self.similarityStats = similarityStats
        self.confidence = confidence
        self.gaps = gaps
    }

    /// Convert to JSON for OpenAI
    func toJSON() -> [String: Any] {
        let isoFormatter = ISO8601DateFormatter()
        var json: [String: Any] = [
            "count": count,
            "confidence": confidence.rawValue
        ]

        if let dateRange = dateRange {
            json["dateRange"] = [
                "start": isoFormatter.string(from: dateRange.start),
                "end": isoFormatter.string(from: dateRange.end),
                "spanDays": dateRange.spanDays
            ]
        }

        if let stats = similarityStats {
            json["similarityStats"] = [
                "median": round(stats.median * 1000) / 1000,
                "iqr": [
                    round(stats.iqr.lower * 1000) / 1000,
                    round(stats.iqr.upper * 1000) / 1000
                ],
                "min": round(stats.min * 1000) / 1000,
                "max": round(stats.max * 1000) / 1000
            ]
        }

        if !gaps.isEmpty {
            json["gaps"] = gaps.map { gap in
                [
                    "start": isoFormatter.string(from: gap.start),
                    "end": isoFormatter.string(from: gap.end),
                    "reason": gap.reason,
                    "spanDays": gap.spanDays
                ]
            }
        }

        return json
    }
}

// MARK: - Array Extensions for Statistics

extension Array where Element == Double {
    func median() -> Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            return sorted[mid]
        }
    }

    func iqr() -> (lower: Double, upper: Double) {
        guard count > 3 else { return (0, 0) }
        let sorted = self.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        return (sorted[q1Index], sorted[q3Index])
    }
}
