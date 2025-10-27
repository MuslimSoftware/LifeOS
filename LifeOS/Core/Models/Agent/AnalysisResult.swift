import Foundation

/// Result from an analyze operation
struct AnalysisResult: Codable {
    let operation: String
    let results: [AnalysisItem]
    let metadata: AnalysisMetadata

    struct AnalysisItem: Codable {
        let id: String?
        let content: [String: Any]

        enum CodingKeys: String, CodingKey {
            case id
        }

        init(id: String? = nil, content: [String: Any]) {
            self.id = id
            self.content = content
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decodeIfPresent(String.self, forKey: .id)

            // Decode remaining keys as content
            let allKeys = try decoder.container(keyedBy: DynamicKey.self)
            var content: [String: Any] = [:]
            for key in allKeys.allKeys where key.stringValue != "id" {
                if let value = try? allKeys.decode(String.self, forKey: key) {
                    content[key.stringValue] = value
                } else if let value = try? allKeys.decode(Int.self, forKey: key) {
                    content[key.stringValue] = value
                } else if let value = try? allKeys.decode(Double.self, forKey: key) {
                    content[key.stringValue] = value
                } else if let value = try? allKeys.decode(Bool.self, forKey: key) {
                    content[key.stringValue] = value
                } else if let value = try? allKeys.decode([String].self, forKey: key) {
                    content[key.stringValue] = value
                }
            }
            self.content = content
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicKey.self)

            if let id = id {
                try container.encode(id, forKey: DynamicKey(stringValue: "id")!)
            }

            for (key, value) in content {
                guard let codingKey = DynamicKey(stringValue: key) else { continue }

                if let stringValue = value as? String {
                    try container.encode(stringValue, forKey: codingKey)
                } else if let intValue = value as? Int {
                    try container.encode(intValue, forKey: codingKey)
                } else if let doubleValue = value as? Double {
                    try container.encode(doubleValue, forKey: codingKey)
                } else if let boolValue = value as? Bool {
                    try container.encode(boolValue, forKey: codingKey)
                } else if let arrayValue = value as? [String] {
                    try container.encode(arrayValue, forKey: codingKey)
                }
            }
        }

        func toJSON() -> [String: Any] {
            var json = content
            if let id = id {
                json["id"] = id
            }
            return json
        }
    }

    struct AnalysisMetadata: Codable {
        let executionTimeSeconds: Double
        let model: String?
        let tokensUsed: Int?
        let confidence: Confidence

        enum Confidence: String, Codable {
            case high
            case medium
            case low
        }

        init(
            executionTimeSeconds: Double,
            model: String? = nil,
            tokensUsed: Int? = nil,
            confidence: Confidence
        ) {
            self.executionTimeSeconds = executionTimeSeconds
            self.model = model
            self.tokensUsed = tokensUsed
            self.confidence = confidence
        }

        func toJSON() -> [String: Any] {
            var json: [String: Any] = [
                "executionTime": "\(executionTimeSeconds)s",
                "confidence": confidence.rawValue
            ]
            if let model = model {
                json["model"] = model
            }
            if let tokens = tokensUsed {
                json["tokensUsed"] = tokens
            }
            return json
        }
    }

    init(
        operation: String,
        results: [AnalysisItem],
        metadata: AnalysisMetadata
    ) {
        self.operation = operation
        self.results = results
        self.metadata = metadata
    }

    /// Convert to JSON-compatible dictionary for OpenAI
    func toJSON() -> [String: Any] {
        return [
            "op": operation,
            "results": results.map { $0.toJSON() },
            "metadata": metadata.toJSON()
        ]
    }
}

// MARK: - Dynamic Coding Key

private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// MARK: - Convenience Builders

extension AnalysisResult {
    /// Create result from raw dictionaries
    static func build(
        operation: String,
        items: [[String: Any]],
        executionTime: Double,
        model: String? = nil,
        confidence: AnalysisMetadata.Confidence = .medium
    ) -> AnalysisResult {
        let analysisItems = items.enumerated().map { (index, item) -> AnalysisItem in
            let id = item["id"] as? String ?? "item-\(index)"
            var content = item
            content.removeValue(forKey: "id")
            return AnalysisItem(id: id, content: content)
        }

        let metadata = AnalysisMetadata(
            executionTimeSeconds: executionTime,
            model: model,
            tokensUsed: nil,
            confidence: confidence
        )

        return AnalysisResult(
            operation: operation,
            results: analysisItems,
            metadata: metadata
        )
    }

    /// Create empty result
    static func empty(
        operation: String,
        reason: String = "No results generated"
    ) -> AnalysisResult {
        let metadata = AnalysisMetadata(
            executionTimeSeconds: 0,
            model: nil,
            tokensUsed: nil,
            confidence: .low
        )

        return AnalysisResult(
            operation: operation,
            results: [],
            metadata: metadata
        )
    }
}
