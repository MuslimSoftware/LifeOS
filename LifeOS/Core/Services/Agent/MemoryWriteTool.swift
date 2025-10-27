import Foundation

/// Tool for saving insights, patterns, and decisions to persistent memory
class MemoryWriteTool: AgentTool {
    let name = "memory_write"
    let description = "Save an insight, decision, rule, or commitment for future reference. Use this to remember important patterns, correlations, or decisions discovered during analysis."

    private let repository: AgentMemoryRepository

    init(repository: AgentMemoryRepository) {
        self.repository = repository
    }

    var parametersSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "kind": [
                    "type": "string",
                    "enum": ["insight", "decision", "todo", "rule", "value", "commitment"],
                    "description": "Type of memory: insight (pattern/observation), decision (choice made), todo (suggested action), rule (correlation/rule of thumb), value (core principle), commitment (promise/commitment)"
                ],
                "content": [
                    "type": "string",
                    "description": "The insight, decision, or rule to remember. Be specific and actionable."
                ],
                "tags": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Tags for categorization (e.g., ['work', 'health', 'relationships'])"
                ],
                "relatedIds": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "IDs of related journal entries or chunks that support this memory"
                ],
                "confidence": [
                    "type": "string",
                    "enum": ["low", "medium", "high"],
                    "description": "Confidence level in this insight"
                ]
            ],
            "required": ["kind", "content"]
        ]
    }

    func execute(arguments: [String: Any]) async throws -> Any {
        // Parse arguments
        guard let kindString = arguments["kind"] as? String,
              let kind = AgentMemory.MemoryKind(rawValue: kindString) else {
            throw ToolError.invalidArguments("Invalid or missing 'kind' parameter")
        }

        guard let content = arguments["content"] as? String, !content.isEmpty else {
            throw ToolError.invalidArguments("Missing or empty 'content' parameter")
        }

        let tags = arguments["tags"] as? [String] ?? []
        let relatedIds = arguments["relatedIds"] as? [String] ?? []

        let confidenceString = arguments["confidence"] as? String ?? "medium"
        let confidence = AgentMemory.Confidence(rawValue: confidenceString) ?? .medium

        // Create memory
        let memory = AgentMemory(
            kind: kind,
            content: content,
            tags: tags,
            relatedIds: relatedIds,
            confidence: confidence
        )

        // Save to database
        try repository.save(memory)

        // Return confirmation
        return [
            "success": true,
            "memoryId": memory.id,
            "kind": kind.rawValue,
            "content": content,
            "tags": tags,
            "confidence": confidence.rawValue,
            "createdAt": ISO8601DateFormatter().string(from: memory.createdAt),
            "message": "Memory saved successfully. This \(kind.rawValue) will be available in future conversations."
        ]
    }
}

// MARK: - Tool Error

enum ToolError: Error, LocalizedError {
    case invalidArguments(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
}
