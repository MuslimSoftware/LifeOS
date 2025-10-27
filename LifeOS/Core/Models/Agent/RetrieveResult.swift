import Foundation

/// Complete result from a retrieve query
struct RetrieveResult: Codable {
    let items: [RankedItem]
    let metadata: RetrieveMetadata

    init(items: [RankedItem], metadata: RetrieveMetadata) {
        self.items = items
        self.metadata = metadata
    }

    /// Convert to JSON-compatible dictionary for OpenAI (full data)
    func toJSON() -> [String: Any] {
        return [
            "items": items.map { $0.toJSON() },
            "metadata": metadata.toJSON()
        ]
    }

    /// Convert to lightweight summary for agent reasoning (prevents token overflow)
    func toSummaryJSON(resultId: String) -> [String: Any] {
        var summary: [String: Any] = [
            "resultId": resultId,
            "count": metadata.count,
            "metadata": metadata.toJSON()
        ]

        // Add human-readable summary
        if let dateRange = metadata.dateRange {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            summary["summary"] = "Retrieved \(metadata.count) items from \(formatter.string(from: dateRange.start)) to \(formatter.string(from: dateRange.end))"
        } else {
            summary["summary"] = "Retrieved \(metadata.count) items"
        }

        // Include preview of first 2 items (truncated)
        let previewItems = items.prefix(2).map { item -> [String: Any] in
            var preview: [String: Any] = [
                "id": item.id,
                "date": ISO8601DateFormatter().string(from: item.date),
                "score": round(item.score * 1000) / 1000
            ]
            if let text = item.text {
                let maxChars = 150
                preview["textPreview"] = String(text.prefix(maxChars)) + (text.count > maxChars ? "..." : "")
            }
            return preview
        }
        summary["preview"] = previewItems

        summary["note"] = "Full data available via resultId '\(resultId)'. Pass to analyze() to generate insights."

        return summary
    }
}

// MARK: - Convenience Builders

extension RetrieveResult {
    /// Build a result from ranked items with automatic metadata computation
    static func build(
        items: [RankedItem],
        gaps: [RetrieveMetadata.DataGap] = []
    ) -> RetrieveResult {
        let dates = items.map { $0.date }
        let similarities = items.compactMap { $0.components.similarity }

        let dateRange = RetrieveMetadata.DateRange(dates: dates)
        let similarityStats = similarities.isEmpty ? nil : RetrieveMetadata.SimilarityStats(similarities: similarities)

        let confidence = RetrieveMetadata.Confidence.compute(
            count: items.count,
            medianSimilarity: similarityStats?.median,
            dateSpan: dateRange?.spanDays
        )

        let metadata = RetrieveMetadata(
            count: items.count,
            dateRange: dateRange,
            similarityStats: similarityStats,
            confidence: confidence,
            gaps: gaps
        )

        return RetrieveResult(items: items, metadata: metadata)
    }

    /// Build empty result with low confidence
    static func empty(reason: String = "No results found") -> RetrieveResult {
        let metadata = RetrieveMetadata(
            count: 0,
            dateRange: nil,
            similarityStats: nil,
            confidence: .low,
            gaps: []
        )
        return RetrieveResult(items: [], metadata: metadata)
    }
}
