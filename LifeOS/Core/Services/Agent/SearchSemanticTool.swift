import Foundation

/// Tool for semantic search through journal entries using natural language queries
class SearchSemanticTool: AgentTool {
    private let vectorSearch: VectorSearchService
    private let chunkRepository: ChunkRepository
    private let openAI: OpenAIService

    let name = "search_semantic"
    let description = "Search through journal entries using natural language. Use this to find past experiences, feelings, or events. Returns relevant journal excerpts with dates and similarity scores."

    let parametersSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "query": [
                "type": "string",
                "description": "Natural language search query (e.g., 'times I felt grateful', 'when I was anxious about work')"
            ],
            "startDate": [
                "type": "string",
                "description": "Optional start date in ISO 8601 format (e.g., '2025-01-01'). If not specified, searches all entries."
            ],
            "endDate": [
                "type": "string",
                "description": "Optional end date in ISO 8601 format (e.g., '2025-12-31'). If not specified, searches up to present."
            ],
            "topK": [
                "type": "integer",
                "description": "Number of results to return (default: 10, max: 20)",
                "default": 10
            ]
        ],
        "required": ["query"]
    ]

    init(vectorSearch: VectorSearchService, chunkRepository: ChunkRepository, openAI: OpenAIService) {
        self.vectorSearch = vectorSearch
        self.chunkRepository = chunkRepository
        self.openAI = openAI
    }

    func execute(arguments: [String: Any]) async throws -> Any {
        // Extract arguments
        guard let query = arguments["query"] as? String else {
            throw ToolError.missingRequiredArgument("query")
        }

        let topK = (arguments["topK"] as? Int) ?? 10
        let limitedTopK = min(topK, 20) // Cap at 20 results

        // Parse optional date range
        var startDate: Date?
        var endDate: Date?

        if let startDateString = arguments["startDate"] as? String {
            startDate = ISO8601DateFormatter().date(from: startDateString)
        }

        if let endDateString = arguments["endDate"] as? String {
            endDate = ISO8601DateFormatter().date(from: endDateString)
        }

        // Generate embedding for the query
        let queryEmbedding = try await openAI.generateEmbedding(for: query)

        // Perform vector search
        let dateRange = (startDate != nil && endDate != nil) ? DateInterval(start: startDate!, end: endDate!) : nil
        let results = try vectorSearch.searchSimilar(
            queryEmbedding: queryEmbedding,
            topK: limitedTopK,
            dateRange: dateRange,
            minSimilarity: 0.5 // Only return reasonably relevant results
        )

        // Format results for the agent
        let formattedResults: [[String: Any]] = results.map { result in
            let isoFormatter = ISO8601DateFormatter()
            return [
                "text": result.chunk.text,
                "date": isoFormatter.string(from: result.chunk.date),
                "similarity": round(result.similarity * 1000) / 1000, // Round to 3 decimals
                "entryId": result.chunk.entryId
            ]
        }

        return [
            "results": formattedResults,
            "count": formattedResults.count,
            "query": query
        ]
    }
}

enum ToolError: Error, LocalizedError {
    case missingRequiredArgument(String)
    case invalidArgumentType(String, expectedType: String)
    case invalidDateFormat(String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredArgument(let arg):
            return "Missing required argument: \(arg)"
        case .invalidArgumentType(let arg, let expectedType):
            return "Invalid type for argument '\(arg)'. Expected: \(expectedType)"
        case .invalidDateFormat(let dateString):
            return "Invalid date format: '\(dateString)'. Expected ISO 8601 format (e.g., '2025-01-01')"
        }
    }
}
