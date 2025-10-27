import Foundation

/// Universal data retrieval tool
/// Replaces: search_semantic, get_month_summary, get_year_summary, get_time_series, and "recent entries" queries
class RetrieveTool: AgentTool {
    let name = "retrieve"
    let description = "Fetch journal data, analytics, or summaries with flexible filtering, sorting, and views. Use this for ALL data retrieval needs."

    private let chunkRepository: ChunkRepository
    private let analyticsRepository: EntryAnalyticsRepository
    private let monthSummaryRepository: MonthSummaryRepository
    private let yearSummaryRepository: YearSummaryRepository
    private let openAI: OpenAIService
    private let bm25: BM25Service
    private let ranker: HybridRanker

    let parametersSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "scope": [
                "type": "string",
                "enum": ["entries", "chunks", "analytics", "summaries"],
                "description": "What type of data to retrieve"
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
        analyticsRepository: EntryAnalyticsRepository,
        monthSummaryRepository: MonthSummaryRepository,
        yearSummaryRepository: YearSummaryRepository,
        openAI: OpenAIService,
        bm25: BM25Service
    ) {
        self.chunkRepository = chunkRepository
        self.analyticsRepository = analyticsRepository
        self.monthSummaryRepository = monthSummaryRepository
        self.yearSummaryRepository = yearSummaryRepository
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
        case .analytics:
            result = try await retrieveAnalytics(query: query)
        case .summaries:
            result = try await retrieveSummaries(query: query)
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

    private func retrieveAnalytics(query: RetrieveQuery) async throws -> RetrieveResult {
        // 1. Fetch analytics from DB
        var analytics = try fetchAnalyticsCandidates(query: query)

        if analytics.isEmpty {
            return RetrieveResult.empty(reason: "No analytics found matching filters")
        }

        // 2. Determine ranking weights
        let weights = RankingWeights.forQuery(query)
        let customRanker = HybridRanker(openAI: openAI, bm25: bm25, weights: weights)

        // 3. Rank
        let rankedItems = try await customRanker.rankAnalytics(analytics, query: query)

        // 4. Apply view transformations (timeline, stats, etc.)
        let viewResult = applyView(items: rankedItems, analytics: analytics, query: query)

        return viewResult
    }

    private func retrieveSummaries(query: RetrieveQuery) async throws -> RetrieveResult {
        guard let granularity = query.filter?.timeGranularity else {
            throw RetrieveQueryError.missingRequiredFilter("timeGranularity")
        }

        switch granularity {
        case .month:
            return try retrieveMonthSummaries(query: query)
        case .year:
            return try retrieveYearSummaries(query: query)
        case .day, .week:
            throw RetrieveQueryError.invalidFilter
        }
    }

    // MARK: - Summary Handlers

    private func retrieveMonthSummaries(query: RetrieveQuery) throws -> RetrieveResult {
        let startDate = query.filter?.dateFrom ?? Date(timeIntervalSince1970: 0)
        let endDate = query.filter?.dateTo ?? Date()

        let summaries = try monthSummaryRepository.getAll()

        let filtered = summaries.filter { summary in
            let summaryDate = Calendar.current.date(from: DateComponents(year: summary.year, month: summary.month)) ?? Date.distantPast
            return summaryDate >= startDate && summaryDate <= endDate
        }

        // Convert to RankedItems
        let items = filtered.map { summary -> RankedItem in
            let date = Calendar.current.date(from: DateComponents(year: summary.year, month: summary.month)) ?? Date()
            return RankedItem(
                id: summary.id.uuidString,
                date: date,
                text: summary.summaryText,
                score: 1.0,
                components: RankedItem.ScoreComponents(),
                provenance: RankedItem.Provenance(
                    source: "summaries",
                    entryId: nil,
                    chunkId: nil,
                    analyticsId: nil
                )
            )
        }.sorted { $0.date > $1.date }

        let limited = Array(items.prefix(query.limit))
        return RetrieveResult.build(items: limited)
    }

    private func retrieveYearSummaries(query: RetrieveQuery) throws -> RetrieveResult {
        let summaries = try yearSummaryRepository.getAll()

        let startYear = Calendar.current.component(.year, from: query.filter?.dateFrom ?? Date(timeIntervalSince1970: 0))
        let endYear = Calendar.current.component(.year, from: query.filter?.dateTo ?? Date())

        let filtered = summaries.filter { summary in
            summary.year >= startYear && summary.year <= endYear
        }

        let items = filtered.map { summary -> RankedItem in
            let date = Calendar.current.date(from: DateComponents(year: summary.year)) ?? Date()
            return RankedItem(
                id: summary.id.uuidString,
                date: date,
                text: summary.summaryText,
                score: 1.0,
                components: RankedItem.ScoreComponents(),
                provenance: RankedItem.Provenance(
                    source: "summaries",
                    entryId: nil,
                    chunkId: nil,
                    analyticsId: nil
                )
            )
        }.sorted { $0.date > $1.date }

        let limited = Array(items.prefix(query.limit))
        return RetrieveResult.build(items: limited)
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

    private func fetchAnalyticsCandidates(query: RetrieveQuery) throws -> [EntryAnalytics] {
        if let dateFrom = query.filter?.dateFrom, let dateTo = query.filter?.dateTo {
            return try analyticsRepository.getAnalytics(from: dateFrom, to: dateTo)
        } else if let dateFrom = query.filter?.dateFrom {
            return try analyticsRepository.getAnalytics(from: dateFrom, to: Date())
        } else {
            return try analyticsRepository.getAllAnalytics()
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

    // MARK: - View Transformations

    private func applyView(items: [RankedItem], analytics: [EntryAnalytics], query: RetrieveQuery) -> RetrieveResult {
        switch query.view {
        case .raw:
            return RetrieveResult.build(items: items)

        case .timeline:
            // Group by date and return daily stats
            return buildTimelineView(analytics: analytics)

        case .stats:
            // Return aggregate statistics
            return buildStatsView(analytics: analytics, query: query)

        case .histogram:
            // Return histogram buckets
            return buildHistogramView(analytics: analytics, query: query)
        }
    }

    private func buildTimelineView(analytics: [EntryAnalytics]) -> RetrieveResult {
        // Group by date, compute daily metrics
        let dailyStats = analytics.map { item -> RankedItem in
            RankedItem(
                id: item.id.uuidString,
                date: item.date,
                text: nil,
                score: item.happinessScore / 100.0,
                components: RankedItem.ScoreComponents(magnitude: item.happinessScore / 100.0),
                provenance: RankedItem.Provenance(
                    source: "analytics",
                    entryId: item.entryId.uuidString,
                    chunkId: nil,
                    analyticsId: item.id.uuidString
                )
            )
        }

        return RetrieveResult.build(items: dailyStats)
    }

    private func buildStatsView(analytics: [EntryAnalytics], query: RetrieveQuery) -> RetrieveResult {
        guard !analytics.isEmpty else {
            return RetrieveResult.empty(reason: "No analytics data")
        }

        let metric = query.filter?.metric ?? .happiness
        let values: [Double]

        switch metric {
        case .happiness:
            values = analytics.map { $0.happinessScore }
        case .stress:
            values = analytics.map { ranker.computeStressScore($0) }
        case .energy:
            values = analytics.map { ranker.computeEnergyScore($0) }
        }

        let avg = values.reduce(0, +) / Double(values.count)
        let min = values.min() ?? 0
        let max = values.max() ?? 0

        // Create a synthetic item with stats
        let statsItem = RankedItem(
            id: "stats",
            date: analytics.last?.date ?? Date(),
            text: "average: \(avg), min: \(min), max: \(max), count: \(analytics.count)",
            score: avg / 100.0,
            components: RankedItem.ScoreComponents(magnitude: avg / 100.0),
            provenance: RankedItem.Provenance(
                source: "analytics",
                entryId: nil,
                chunkId: nil,
                analyticsId: nil
            )
        )

        return RetrieveResult.build(items: [statsItem])
    }

    private func buildHistogramView(analytics: [EntryAnalytics], query: RetrieveQuery) -> RetrieveResult {
        // For now, return empty - can implement histogram bucketing later
        return RetrieveResult.empty(reason: "Histogram view not yet implemented")
    }
}

// MARK: - Helper Extension

private extension HybridRanker {
    func computeStressScore(_ analytics: EntryAnalytics) -> Double {
        let emotions = analytics.emotions
        let stressScore = 50 + (emotions.anxiety * 20) + (emotions.sadness * 15) + (emotions.anger * 10)
        return min(max(stressScore, 0), 100)
    }

    func computeEnergyScore(_ analytics: EntryAnalytics) -> Double {
        let energyScore = 50 + (analytics.arousal * 30) + (analytics.emotions.joy * 15)
        return min(max(energyScore, 0), 100)
    }
}
