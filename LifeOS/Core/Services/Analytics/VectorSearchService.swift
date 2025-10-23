import Foundation
import Accelerate

/// Result from semantic search
struct SemanticSearchResult {
    let chunk: JournalChunk
    let similarity: Float
    let rank: Int
}

/// Service for semantic search using vector embeddings
class VectorSearchService {
    private let chunkRepository: ChunkRepository

    init(chunkRepository: ChunkRepository = ChunkRepository()) {
        self.chunkRepository = chunkRepository
    }

    /// Search for chunks semantically similar to the query embedding
    /// - Parameters:
    ///   - queryEmbedding: The embedding vector for the search query
    ///   - topK: Number of results to return
    ///   - dateRange: Optional date range filter
    ///   - minSimilarity: Minimum similarity threshold (0-1)
    /// - Returns: Array of search results sorted by similarity (descending)
    func searchSimilar(
        queryEmbedding: [Float],
        topK: Int = 10,
        dateRange: DateInterval? = nil,
        minSimilarity: Float = 0.3
    ) throws -> [SemanticSearchResult] {
        // Get candidate chunks
        let chunks: [JournalChunk]
        if let dateRange = dateRange {
            chunks = try chunkRepository.getChunks(from: dateRange.start, to: dateRange.end)
        } else {
            chunks = try chunkRepository.getAllChunks()
        }

        // Filter out chunks without embeddings
        let chunksWithEmbeddings = chunks.compactMap { chunk -> (JournalChunk, [Float])? in
            guard let embedding = chunk.embedding else { return nil }
            return (chunk, embedding)
        }

        // Compute similarities
        var results: [(chunk: JournalChunk, similarity: Float)] = []
        for (chunk, embedding) in chunksWithEmbeddings {
            let similarity = cosineSimilarity(queryEmbedding, embedding)
            if similarity >= minSimilarity {
                results.append((chunk, similarity))
            }
        }

        // Sort by similarity (descending) and take topK
        results.sort { $0.similarity > $1.similarity }
        let topResults = Array(results.prefix(topK))

        // Convert to search results with rank
        return topResults.enumerated().map { index, item in
            SemanticSearchResult(
                chunk: item.chunk,
                similarity: item.similarity,
                rank: index + 1
            )
        }
    }

    /// Compute cosine similarity between two vectors using Accelerate
    /// - Parameters:
    ///   - a: First vector
    ///   - b: Second vector
    /// - Returns: Similarity score between -1 and 1 (typically 0-1 for embeddings)
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else {
            print("⚠️ Vector dimension mismatch: \(a.count) vs \(b.count)")
            return 0
        }

        let n = vDSP_Length(a.count)

        // Compute dot product
        var dotProduct: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dotProduct, n)

        // Compute magnitudes
        var magnitudeA: Float = 0
        var magnitudeB: Float = 0
        vDSP_svesq(a, 1, &magnitudeA, n)  // Sum of squares for A
        vDSP_svesq(b, 1, &magnitudeB, n)  // Sum of squares for B

        magnitudeA = sqrt(magnitudeA)
        magnitudeB = sqrt(magnitudeB)

        // Avoid division by zero
        guard magnitudeA > 0 && magnitudeB > 0 else {
            return 0
        }

        return dotProduct / (magnitudeA * magnitudeB)
    }

    /// Hybrid search: combine keyword matching with semantic search
    /// - Parameters:
    ///   - queryEmbedding: Embedding for semantic search
    ///   - keywords: Keywords for text matching
    ///   - topK: Number of results
    ///   - dateRange: Optional date filter
    ///   - semanticWeight: Weight for semantic vs keyword (0-1, default 0.7)
    /// - Returns: Combined search results
    func hybridSearch(
        queryEmbedding: [Float],
        keywords: [String],
        topK: Int = 10,
        dateRange: DateInterval? = nil,
        semanticWeight: Float = 0.7
    ) throws -> [SemanticSearchResult] {
        // Get semantic results
        let semanticResults = try searchSimilar(
            queryEmbedding: queryEmbedding,
            topK: topK * 2,  // Get more candidates for reranking
            dateRange: dateRange,
            minSimilarity: 0.2
        )

        // Rerank with keyword matching
        let keywordWeight = 1.0 - semanticWeight
        var scoredResults: [(result: SemanticSearchResult, finalScore: Float)] = []

        for result in semanticResults {
            let keywordScore = calculateKeywordScore(result.chunk.text, keywords: keywords)
            let finalScore = semanticWeight * result.similarity + keywordWeight * keywordScore
            scoredResults.append((result, finalScore))
        }

        // Sort by final score and take topK
        scoredResults.sort { $0.finalScore > $1.finalScore }
        let topResults = Array(scoredResults.prefix(topK))

        // Return with updated rankings
        return topResults.enumerated().map { index, item in
            SemanticSearchResult(
                chunk: item.result.chunk,
                similarity: item.finalScore,
                rank: index + 1
            )
        }
    }

    // MARK: - Private Helpers

    /// Calculate keyword matching score (simple term frequency)
    private func calculateKeywordScore(_ text: String, keywords: [String]) -> Float {
        guard !keywords.isEmpty else { return 0 }

        let lowercasedText = text.lowercased()
        var matchCount = 0

        for keyword in keywords {
            let lowercasedKeyword = keyword.lowercased()
            let ranges = lowercasedText.ranges(of: lowercasedKeyword)
            matchCount += ranges.count
        }

        // Normalize by number of keywords (simple TF)
        return min(Float(matchCount) / Float(keywords.count), 1.0)
    }
}

// Extension for finding all ranges of a substring
private extension String {
    func ranges(of searchString: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchRange = self.startIndex..<self.endIndex

        while let range = self.range(of: searchString, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<self.endIndex
        }

        return ranges
    }
}
