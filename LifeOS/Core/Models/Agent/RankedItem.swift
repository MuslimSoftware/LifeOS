import Foundation

/// Represents a search result with ranking scores and provenance
struct RankedItem: Codable {
    let id: String
    let date: Date
    let text: String?
    let score: Double
    let components: ScoreComponents
    let provenance: Provenance
    let metadata: [String: Any]?

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
        let source: String  // "chunks", "analytics", "summaries", "memory"
        let entryId: String?
        let chunkId: String?
        let analyticsId: String?
        let memoryId: String?
    }

    init(
        id: String,
        date: Date,
        text: String? = nil,
        score: Double,
        components: ScoreComponents,
        provenance: Provenance,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.date = date
        self.text = text
        self.score = score
        self.components = components
        self.provenance = provenance
        self.metadata = metadata
    }

    // Custom Codable implementation to handle metadata dictionary
    enum CodingKeys: String, CodingKey {
        case id, date, text, score, components, provenance, metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        score = try container.decode(Double.self, forKey: .score)
        components = try container.decode(ScoreComponents.self, forKey: .components)
        provenance = try container.decode(Provenance.self, forKey: .provenance)
        metadata = nil  // Skip decoding metadata for now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encode(score, forKey: .score)
        try container.encode(components, forKey: .components)
        try container.encode(provenance, forKey: .provenance)
        // Skip encoding metadata - it will be added to JSON in toJSON()
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

        // Add metadata if present
        if let metadata = metadata {
            json["metadata"] = metadata
        }

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
                analyticsId: nil,
                memoryId: nil
            )
        )
    }

}
