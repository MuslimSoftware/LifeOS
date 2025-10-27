import Foundation

/// Represents a search result with ranking scores and provenance
struct RankedItem: Codable {
    let id: String
    let date: Date
    let text: String?
    let score: Double
    let components: ScoreComponents
    let provenance: Provenance

    struct ScoreComponents: Codable {
        var similarity: Double?
        var recencyDecay: Double?
        var keywordMatch: Double?
        var magnitude: Double?

        init(
            similarity: Double? = nil,
            recencyDecay: Double? = nil,
            keywordMatch: Double? = nil,
            magnitude: Double? = nil
        ) {
            self.similarity = similarity
            self.recencyDecay = recencyDecay
            self.keywordMatch = keywordMatch
            self.magnitude = magnitude
        }
    }

    struct Provenance: Codable {
        let source: String  // "chunks", "analytics", "summaries"
        let entryId: String?
        let chunkId: String?
        let analyticsId: String?
    }

    init(
        id: String,
        date: Date,
        text: String? = nil,
        score: Double,
        components: ScoreComponents,
        provenance: Provenance
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.score = score
        self.components = components
        self.provenance = provenance
    }

    /// Convert to JSON-compatible dictionary for OpenAI
    func toJSON() -> [String: Any] {
        let isoFormatter = ISO8601DateFormatter()
        var json: [String: Any] = [
            "id": id,
            "date": isoFormatter.string(from: date),
            "score": round(score * 1000) / 1000
        ]

        if let text = text {
            json["text"] = text
        }

        // Add score components (non-nil only)
        var componentsJSON: [String: Any] = [:]
        if let sim = components.similarity {
            componentsJSON["similarity"] = round(sim * 1000) / 1000
        }
        if let rec = components.recencyDecay {
            componentsJSON["recencyDecay"] = round(rec * 1000) / 1000
        }
        if let kw = components.keywordMatch {
            componentsJSON["keywordMatch"] = round(kw * 1000) / 1000
        }
        if let mag = components.magnitude {
            componentsJSON["magnitude"] = round(mag * 1000) / 1000
        }
        json["scoreComponents"] = componentsJSON

        // Provenance
        var provenanceJSON: [String: Any] = ["source": provenance.source]
        if let entryId = provenance.entryId {
            provenanceJSON["entryId"] = entryId
        }
        if let chunkId = provenance.chunkId {
            provenanceJSON["chunkId"] = chunkId
        }
        if let analyticsId = provenance.analyticsId {
            provenanceJSON["analyticsId"] = analyticsId
        }
        json["provenance"] = provenanceJSON

        return json
    }
}

// MARK: - Convenience Initializers

extension RankedItem {
    /// Create from a JournalChunk
    static func fromChunk(
        _ chunk: JournalChunk,
        score: Double,
        components: ScoreComponents
    ) -> RankedItem {
        RankedItem(
            id: chunk.id.uuidString,
            date: chunk.date,
            text: chunk.text,
            score: score,
            components: components,
            provenance: Provenance(
                source: "chunks",
                entryId: chunk.entryId.uuidString,
                chunkId: chunk.id.uuidString,
                analyticsId: nil
            )
        )
    }

    /// Create from EntryAnalytics
    static func fromAnalytics(
        _ analytics: EntryAnalytics,
        score: Double,
        components: ScoreComponents
    ) -> RankedItem {
        RankedItem(
            id: analytics.id.uuidString,
            date: analytics.date,
            text: nil,  // Analytics don't have text
            score: score,
            components: components,
            provenance: Provenance(
                source: "analytics",
                entryId: analytics.entryId.uuidString,
                chunkId: nil,
                analyticsId: analytics.id.uuidString
            )
        )
    }
}
