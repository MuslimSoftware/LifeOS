import Foundation
import GRDB

/// Represents a piece of persistent memory saved by the AI agent
/// These are insights, patterns, decisions, or rules learned from journal analysis
struct AgentMemory: Codable {
    /// Unique identifier
    let id: String

    /// Type of memory
    let kind: MemoryKind

    /// The actual content/insight
    let content: String

    /// Tags for categorization and retrieval
    let tags: [String]

    /// IDs of related journal entries or chunks
    let relatedIds: [String]

    /// Confidence level in this insight
    let confidence: Confidence

    /// When this memory was created
    let createdAt: Date

    /// Last time this memory was accessed/used
    var lastAccessed: Date?

    /// Number of times this memory has been accessed
    var accessCount: Int

    enum MemoryKind: String, Codable {
        case insight      // General insight about patterns
        case decision     // Important decision made
        case todo         // Suggested action item
        case rule         // Rule of thumb or correlation
        case value        // Core value or principle
        case commitment   // Commitment or promise made
    }

    enum Confidence: String, Codable {
        case low
        case medium
        case high
    }

    init(
        id: String = UUID().uuidString,
        kind: MemoryKind,
        content: String,
        tags: [String] = [],
        relatedIds: [String] = [],
        confidence: Confidence = .medium,
        createdAt: Date = Date(),
        lastAccessed: Date? = nil,
        accessCount: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.tags = tags
        self.relatedIds = relatedIds
        self.confidence = confidence
        self.createdAt = createdAt
        self.lastAccessed = lastAccessed
        self.accessCount = accessCount
    }
}

// MARK: - GRDB Record

extension AgentMemory: FetchableRecord, PersistableRecord {
    static let databaseTableName = "agent_memory"

    enum Columns {
        static let id = Column("id")
        static let kind = Column("kind")
        static let content = Column("content")
        static let tagsJSON = Column("tags_json")
        static let relatedIdsJSON = Column("related_ids_json")
        static let confidence = Column("confidence")
        static let createdAt = Column("created_at")
        static let lastAccessed = Column("last_accessed")
        static let accessCount = Column("access_count")
    }

    init(row: Row) throws {
        id = row[Columns.id]
        kind = MemoryKind(rawValue: row[Columns.kind]) ?? .insight
        content = row[Columns.content]
        confidence = Confidence(rawValue: row[Columns.confidence]) ?? .medium
        createdAt = row[Columns.createdAt]
        lastAccessed = row[Columns.lastAccessed]
        accessCount = row[Columns.accessCount]

        // Decode JSON arrays
        if let tagsJSONString: String = row[Columns.tagsJSON],
           let tagsData = tagsJSONString.data(using: .utf8),
           let decodedTags = try? JSONDecoder().decode([String].self, from: tagsData) {
            tags = decodedTags
        } else {
            tags = []
        }

        if let relatedIdsJSONString: String = row[Columns.relatedIdsJSON],
           let relatedIdsData = relatedIdsJSONString.data(using: .utf8),
           let decodedIds = try? JSONDecoder().decode([String].self, from: relatedIdsData) {
            relatedIds = decodedIds
        } else {
            relatedIds = []
        }
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.kind] = kind.rawValue
        container[Columns.content] = content
        container[Columns.confidence] = confidence.rawValue
        container[Columns.createdAt] = createdAt
        container[Columns.lastAccessed] = lastAccessed
        container[Columns.accessCount] = accessCount

        // Encode arrays as JSON
        let tagsData = try JSONEncoder().encode(tags)
        container[Columns.tagsJSON] = String(data: tagsData, encoding: .utf8)

        let relatedIdsData = try JSONEncoder().encode(relatedIds)
        container[Columns.relatedIdsJSON] = String(data: relatedIdsData, encoding: .utf8)
    }
}

// MARK: - JSON Helpers

extension AgentMemory {
    /// Convert to JSON dictionary for tool output
    func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "id": id,
            "kind": kind.rawValue,
            "content": content,
            "confidence": confidence.rawValue,
            "createdAt": ISO8601DateFormatter().string(from: createdAt),
            "accessCount": accessCount
        ]

        if !tags.isEmpty {
            json["tags"] = tags
        }

        if !relatedIds.isEmpty {
            json["relatedIds"] = relatedIds
        }

        if let accessed = lastAccessed {
            json["lastAccessed"] = ISO8601DateFormatter().string(from: accessed)
        }

        return json
    }
}
