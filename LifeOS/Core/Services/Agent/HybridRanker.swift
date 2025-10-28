import Foundation
import Accelerate

/// Hybrid ranking service that combines multiple signals:
/// - Semantic similarity (vector embeddings)
/// - Recency decay (exponential time-based)
/// - Keyword matching (BM25)
/// - Metric magnitude (happiness/stress/energy scores)
class HybridRanker {
    private let openAI: OpenAIService
    private let bm25: BM25Service
    private let weights: RankingWeights

    init(
        openAI: OpenAIService,
        bm25: BM25Service,
        weights: RankingWeights = .default
    ) {
        self.openAI = openAI
        self.bm25 = bm25
        self.weights = weights
    }

    /// Rank chunks using hybrid scoring
    /// - Parameters:
    ///   - chunks: Candidate chunks to rank
    ///   - query: The retrieve query with filters
    /// - Returns: Sorted array of ranked items
    func rankChunks(
        _ chunks: [JournalChunk],
        query: RetrieveQuery
    ) async throws -> [RankedItem] {
        guard !chunks.isEmpty else { return [] }

        // Generate embedding if semantic search requested
        var queryEmbedding: [Float]? = nil
        if let similarTo = query.filter?.similarTo {
            queryEmbedding = try await openAI.generateEmbedding(for: similarTo)
        }

        // Get BM25 scores if keyword search requested
        var bm25Scores: [String: Double] = [:]
        if let keyword = query.filter?.keyword {
            let chunkIds = chunks.map { $0.id.uuidString }
            bm25Scores = try bm25.scoreBatch(keyword: keyword, chunkIds: chunkIds)
        }

        let now = Date()
        var scoredItems: [(chunk: JournalChunk, score: Double, components: RankedItem.ScoreComponents)] = []

        for chunk in chunks {
            var totalScore = 0.0
            var components = RankedItem.ScoreComponents()

            // 1. Similarity component
            if let qEmb = queryEmbedding, let chunkEmb = chunk.embedding {
                let similarity = cosineSimilarity(qEmb, chunkEmb)
                components.similarity = Double(similarity)
                totalScore += weights.similarity * Double(similarity)
            }

            // 2. Recency component
            let ageDays = now.timeIntervalSince(chunk.date) / 86400
            let recencyDecay = exp(-log(2) * ageDays / Double(weights.recencyHalfLife))
            components.recencyDecay = recencyDecay
            totalScore += weights.recency * recencyDecay

            // 3. Keyword component
            if let keyword = query.filter?.keyword {
                let keywordScore = bm25Scores[chunk.id.uuidString] ?? 0.0
                components.keywordMatch = keywordScore
                totalScore += weights.keyword * keywordScore
            }

            // 4. Metric magnitude component (not applicable for chunks)
            // This is used for analytics scope

            scoredItems.append((chunk, totalScore, components))
        }

        // Sort by score descending
        scoredItems.sort { $0.score > $1.score }

        // Apply limit
        let limited = Array(scoredItems.prefix(query.limit))

        // Convert to RankedItem
        return limited.map { item in
            RankedItem.fromChunk(item.chunk, score: item.score, components: item.components)
        }
    }

    /// Rank analytics using hybrid scoring
    // MARK: - Private Helpers

    /// Compute cosine similarity using Accelerate framework
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        let n = vDSP_Length(a.count)

        var dotProduct: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dotProduct, n)

        var magnitudeA: Float = 0
        var magnitudeB: Float = 0
        vDSP_svesq(a, 1, &magnitudeA, n)
        vDSP_svesq(b, 1, &magnitudeB, n)

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }

        return dotProduct / (sqrt(magnitudeA) * sqrt(magnitudeB))
    }
}

// MARK: - Ranking Weights

struct RankingWeights {
    let similarity: Double
    let recency: Double
    let keyword: Double
    let metricMagnitude: Double
    let recencyHalfLife: Int  // in days

    /// Default weights: balanced hybrid
    static let `default` = RankingWeights(
        similarity: 0.4,
        recency: 0.3,
        keyword: 0.2,
        metricMagnitude: 0.1,
        recencyHalfLife: 30
    )

    /// Latest queries: prioritize recency
    static let latest = RankingWeights(
        similarity: 0.0,
        recency: 0.8,
        keyword: 0.2,
        metricMagnitude: 0.0,
        recencyHalfLife: 21
    )

    /// Current state queries: balance recent + semantic
    static let currentState = RankingWeights(
        similarity: 0.2,
        recency: 0.5,
        keyword: 0.1,
        metricMagnitude: 0.2,
        recencyHalfLife: 30
    )

    /// Lifelong pattern queries: disable recency
    static let lifelong = RankingWeights(
        similarity: 0.5,
        recency: 0.0,
        keyword: 0.3,
        metricMagnitude: 0.2,
        recencyHalfLife: 9999
    )

    /// Semantic queries: prioritize similarity
    static let semantic = RankingWeights(
        similarity: 0.6,
        recency: 0.2,
        keyword: 0.1,
        metricMagnitude: 0.1,
        recencyHalfLife: 60
    )

    /// Determine weights based on query characteristics
    static func forQuery(_ query: RetrieveQuery) -> RankingWeights {
        // If explicit recency half-life specified, use it
        if let halfLife = query.filter?.recencyHalfLife {
            if halfLife > 1000 {
                return .lifelong
            } else if halfLife < 25 {
                return .latest
            }
        }

        // If sorting by date, use latest weights
        if query.sort.isRecencyBased {
            return .latest
        }

        // If semantic search with no keyword, use semantic weights
        if query.filter?.similarTo != nil && query.filter?.keyword == nil {
            return .semantic
        }

        // Default: balanced
        return .default
    }
}
