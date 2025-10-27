import Foundation
import GRDB

/// Service for keyword-based full-text search using SQLite FTS5 BM25 ranking
/// BM25 is a probabilistic ranking function that considers:
/// - Term frequency (TF): How often does the keyword appear in the document?
/// - Inverse document frequency (IDF): How rare is the keyword across all documents?
/// - Document length normalization: Penalizes very long documents
class BM25Service {
    private let dbService: DatabaseService

    init(dbService: DatabaseService = .shared) {
        self.dbService = dbService
    }

    /// Search for chunks matching the keyword query using BM25 ranking
    /// - Parameters:
    ///   - keyword: Search query (can include FTS5 operators like AND, OR, NOT)
    ///   - limit: Maximum number of results
    /// - Returns: Array of chunk IDs with their BM25 scores
    func search(keyword: String, limit: Int = 100) throws -> [(chunkId: String, score: Double)] {
        guard !keyword.isEmpty else { return [] }

        let results = try dbService.getQueue().read { db -> [(String, Double)] in
            let rows = try Row.fetchAll(db, sql: """
                SELECT chunks.id, bm25(chunks_fts) as bm25_score
                FROM chunks_fts
                JOIN chunks ON chunks.rowid = chunks_fts.rowid
                WHERE chunks_fts MATCH ?
                ORDER BY bm25_score
                LIMIT ?
            """, arguments: [keyword, limit])

            return rows.map { row in
                let chunkId: String = row["id"]
                let rawScore: Double = row["bm25_score"]
                // BM25 scores are negative (closer to 0 is better)
                // Convert to positive and normalize
                let normalizedScore = normalizeBM25Score(rawScore)
                return (chunkId, normalizedScore)
            }
        }

        return results
    }

    /// Get BM25 score for a specific chunk and keyword
    /// - Parameters:
    ///   - keyword: Search query
    ///   - chunkId: The chunk UUID to score
    /// - Returns: Normalized BM25 score (0-1), or 0 if no match
    func score(keyword: String, chunkId: String) throws -> Double {
        guard !keyword.isEmpty else { return 0 }

        let result = try dbService.getQueue().read { db -> Double? in
            try Double.fetchOne(db, sql: """
                SELECT bm25(chunks_fts) as bm25_score
                FROM chunks_fts
                JOIN chunks ON chunks.rowid = chunks_fts.rowid
                WHERE chunks.id = ? AND chunks_fts MATCH ?
            """, arguments: [chunkId, keyword])
        }

        guard let rawScore = result else { return 0 }
        return normalizeBM25Score(rawScore)
    }

    /// Get BM25 scores for multiple chunks
    /// - Parameters:
    ///   - keyword: Search query
    ///   - chunkIds: Array of chunk UUIDs to score
    /// - Returns: Dictionary mapping chunk ID to normalized score
    func scoreBatch(keyword: String, chunkIds: [String]) throws -> [String: Double] {
        guard !keyword.isEmpty, !chunkIds.isEmpty else { return [:] }

        let placeholders = chunkIds.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT chunks.id, bm25(chunks_fts) as bm25_score
            FROM chunks_fts
            JOIN chunks ON chunks.rowid = chunks_fts.rowid
            WHERE chunks.id IN (\(placeholders)) AND chunks_fts MATCH ?
        """

        var arguments: [DatabaseValueConvertible] = chunkIds
        arguments.append(keyword)

        let results = try dbService.getQueue().read { db -> [String: Double] in
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            var scores: [String: Double] = [:]
            for row in rows {
                let chunkId: String = row["id"]
                let rawScore: Double = row["bm25_score"]
                scores[chunkId] = normalizeBM25Score(rawScore)
            }
            return scores
        }

        // Fill in 0.0 for chunks that didn't match
        var allScores: [String: Double] = [:]
        for chunkId in chunkIds {
            allScores[chunkId] = results[chunkId] ?? 0.0
        }

        return allScores
    }

    // MARK: - Private Helpers

    /// Normalize BM25 scores to [0, 1] range
    /// SQLite BM25 returns negative scores (closer to 0 is better)
    /// We convert to positive range where higher is better
    /// Typical BM25 range is roughly -20 to 0
    private func normalizeBM25Score(_ rawScore: Double) -> Double {
        // Invert (make positive) and cap at reasonable range
        let inverted = -rawScore
        // Normalize to [0, 1] assuming max score of ~20
        let normalized = min(inverted / 20.0, 1.0)
        return max(normalized, 0.0)
    }
}

// MARK: - FTS5 Query Helpers

extension BM25Service {
    /// Build an FTS5 query from keywords with optional operators
    /// - Parameters:
    ///   - keywords: Array of keywords
    ///   - operator: Logical operator (AND, OR)
    /// - Returns: FTS5-formatted query string
    static func buildQuery(keywords: [String], operator op: FTS5Operator = .and) -> String {
        guard !keywords.isEmpty else { return "" }

        // Escape and quote each keyword
        let escaped = keywords.map { keyword in
            // Escape double quotes
            let escaped = keyword.replacingOccurrences(of: "\"", with: "\"\"")
            // Quote if contains spaces or special chars
            if escaped.contains(" ") || escaped.contains(":") {
                return "\"\(escaped)\""
            }
            return escaped
        }

        let separator = op == .and ? " AND " : " OR "
        return escaped.joined(separator: separator)
    }

    enum FTS5Operator {
        case and
        case or
    }
}
