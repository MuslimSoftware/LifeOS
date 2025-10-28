import Foundation

/// Universal data retrieval tool
/// Replaces: search_semantic, get_month_summary, get_year_summary, get_time_series, and "recent entries" queries
class RetrieveTool: AgentTool {
    let name = "retrieve"
    let description = "Fetch journal data, analytics, or summaries with flexible filtering, sorting, and views. Use this for ALL data retrieval needs."

    private let chunkRepository: ChunkRepository
    private let memoryRepository: AgentMemoryRepository?
    private let openAI: OpenAIService
    private let bm25: BM25Service
    private let ranker: HybridRanker

    let parametersSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "scope": [
                "type": "string",
                "enum": ["entries", "chunks", "memory"],
                "description": "What type of data to retrieve. Use 'memory' to access saved insights and rules."
            ],
            "filter": [
                "type": "object",
                "description": "Filtering criteria",
                "properties": [
                    "dateFrom": [
                        "type": "string",
                        "description": "Start date (ISO 8601, e.g., '2025-01-01')"
                    ],
                    "dateTo": [
                        "type": "string",
                        "description": "End date (ISO 8601)"
                    ],
                    "ids": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Specific entry/chunk IDs"
                    ],
                    "entities": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Filter by entities (people, places, projects)"
                    ],
                    "topics": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Filter by topics/themes"
                    ],
                    "sentiment": [
                        "type": "string",
                        "enum": ["positive", "negative", "neutral"],
                        "description": "Filter by sentiment"
                    ],
                    "metric": [
                        "type": "string",
                        "enum": ["happiness", "stress", "energy"],
                        "description": "Which metric to retrieve (for analytics scope)"
                    ],
                    "similarTo": [
                        "type": "string",
                        "description": "Natural language query for semantic search. IMPORTANT: Do NOT use this for 'latest', 'recent', 'yesterday', or 'last entry' queries - use sort=date_desc instead."
                    ],
                    "keyword": [
                        "type": "string",
                        "description": "Keyword for full-text search"
                    ],
                    "minSimilarity": [
                        "type": "number",
                        "description": "Minimum similarity threshold (0-1, default: 0.4)",
                        "default": 0.4
                    ],
                    "timeGranularity": [
                        "type": "string",
                        "enum": ["day", "week", "month", "year"],
                        "description": "Time bucketing for summaries"
                    ],
                    "recencyHalfLife": [
                        "type": "integer",
                        "description": "Recency decay half-life in days (default: 30, lifelong: 9999)",
                        "default": 30
                    ]
                ]
            ],
            "sort": [
                "type": "string",
                "enum": ["date_desc", "date_asc", "similarity_desc", "magnitude_desc", "hybrid"],
                "default": "hybrid",
                "description": "How to sort results. Use date_desc for 'latest' or 'recent' queries."
            ],
            "limit": [
                "type": "integer",
                "minimum": 1,
                "maximum": 200,
                "default": 10,
                "description": "Maximum number of results"
            ],
            "view": [
                "type": "string",
                "enum": ["raw", "timeline", "stats", "histogram"],
                "default": "raw",
                "description": "Output format"
            ]
        ],
        "required": ["scope"]
    ]

    init(
        chunkRepository: ChunkRepository,
        memoryRepository: AgentMemoryRepository? = nil,
        openAI: OpenAIService,
        bm25: BM25Service
    ) {
        self.chunkRepository = chunkRepository
        self.memoryRepository = memoryRepository
        self.openAI = openAI
        self.bm25 = bm25
        self.ranker = HybridRanker(openAI: openAI, bm25: bm25)
    }

    func execute(arguments: [String: Any]) async throws -> Any {
        // Parse query
        let query = try RetrieveQuery(arguments: arguments)

        print("🔍 [Retrieve] Scope: \(query.scope), Sort: \(query.sort), Limit: \(query.limit)")

        // Route to appropriate retrieval method
        let result: RetrieveResult
        switch query.scope {
        case .chunks:
            result = try await retrieveChunks(query: query)
        case .entries:
            result = try await retrieveEntries(query: query)
        case .memory:
            result = try retrieveMemory(query: query)
        }

        print("🔍 [Retrieve] Found \(result.metadata.count) results (confidence: \(result.metadata.confidence))")

        return result.toJSON()
    }

    // MARK: - Scope Handlers

    private func retrieveChunks(query: RetrieveQuery) async throws -> RetrieveResult {
        // 1. Fetch candidates from DB
        var candidates = try fetchChunkCandidates(query: query)

        // 2. Apply entity/topic filters
        candidates = applyTextFilters(chunks: candidates, query: query)

        // 3. Check if we have minimum similarity threshold
        if candidates.isEmpty {
            return RetrieveResult.empty(reason: "No chunks found matching filters")
        }

        // 4. Determine ranking weights
        let weights = RankingWeights.forQuery(query)
        let customRanker = HybridRanker(openAI: openAI, bm25: bm25, weights: weights)

        // 5. Rank with hybrid scorer
        let rankedItems = try await customRanker.rankChunks(candidates, query: query)

        // 6. Filter by minimum similarity if specified
        let filtered = filterBySimilarity(items: rankedItems, query: query)

        // 7. Build result with metadata
        return RetrieveResult.build(items: filtered)
    }

    private func retrieveEntries(query: RetrieveQuery) async throws -> RetrieveResult {
        // For now, entries scope redirects to chunks with grouping by entry
        // In the future, this could fetch full entry text
        let chunksResult = try await retrieveChunks(query: query)

        // Group by entry and take first chunk from each
        var seenEntries = Set<String>()
        let uniqueItems = chunksResult.items.filter { item in
            guard let entryId = item.provenance.entryId else { return false }
            if seenEntries.contains(entryId) {
                return false
            }
            seenEntries.insert(entryId)
            return true
        }

        return RetrieveResult.build(items: uniqueItems)
    }

    // MARK: - Database Fetching

    private func fetchChunkCandidates(query: RetrieveQuery) throws -> [JournalChunk] {
        if let dateFrom = query.filter?.dateFrom, let dateTo = query.filter?.dateTo {
            return try chunkRepository.getChunks(from: dateFrom, to: dateTo)
        } else if let dateFrom = query.filter?.dateFrom {
            return try chunkRepository.getChunks(from: dateFrom, to: Date())
        } else if let dateTo = query.filter?.dateTo {
            return try chunkRepository.getChunks(from: Date(timeIntervalSince1970: 0), to: dateTo)
        } else {
            return try chunkRepository.getAllChunks()
        }
    }

    // MARK: - Filtering Helpers

    private func applyTextFilters(chunks: [JournalChunk], query: RetrieveQuery) -> [JournalChunk] {
        var filtered = chunks

        // Entity filter
        if let entities = query.filter?.entities {
            filtered = filtered.filter { chunk in
                entities.contains { entity in
                    chunk.text.localizedCaseInsensitiveContains(entity)
                }
            }
        }

        // Topic filter (same as entity for now)
        if let topics = query.filter?.topics {
            filtered = filtered.filter { chunk in
                topics.contains { topic in
                    chunk.text.localizedCaseInsensitiveContains(topic)
                }
            }
        }

        return filtered
    }

    private func filterBySimilarity(items: [RankedItem], query: RetrieveQuery) -> [RankedItem] {
        guard let minSim = query.filter?.minSimilarity else { return items }

        return items.filter { item in
            if let similarity = item.components.similarity {
                return similarity >= minSim
            }
            return true  // Keep items without similarity score
        }
    }


    private func retrieveMemory(query: RetrieveQuery) throws -> RetrieveResult {
        guard let memoryRepo = memoryRepository else {
            return RetrieveResult.empty(reason: "Memory repository not available")
        }

        // 1. Fetch memories based on filters
        var memories: [AgentMemory] = []

        if let tags = query.filter?.topics, !tags.isEmpty {
            // Search by tags (topics field maps to tags)
            memories = try memoryRepo.findByTags(tags)
        } else if let dateFrom = query.filter?.dateFrom, let dateTo = query.filter?.dateTo {
            // Search by date range
            memories = try memoryRepo.findByDateRange(from: dateFrom, to: dateTo)
        } else {
            // Get recent memories
            memories = try memoryRepo.getRecent(limit: query.limit)
        }

        // 2. Sort memories
        switch query.sort {
        case .dateDesc:
            memories.sort { $0.createdAt > $1.createdAt }
        case .dateAsc:
            memories.sort { $0.createdAt < $1.createdAt }
        default:
            // Default to most recent first
            memories.sort { $0.createdAt > $1.createdAt }
        }

        // 3. Limit results
        let limitedMemories = Array(memories.prefix(query.limit))

        // 4. Update access times
        for memory in limitedMemories {
            try? memoryRepo.updateAccessTime(memory.id)
        }

        // 5. Convert to RankedItems
        let items = limitedMemories.map { memory -> RankedItem in
            let provenance = RankedItem.Provenance(
                source: "memory",
                entryId: nil,
                chunkId: nil,
                analyticsId: nil,
                memoryId: memory.id
            )

            return RankedItem(
                id: memory.id,
                date: memory.createdAt,
                text: memory.content,
                score: 1.0,
                components: RankedItem.ScoreComponents(),
                provenance: provenance
            )
        }

        return RetrieveResult.build(items: items)
    }
}
