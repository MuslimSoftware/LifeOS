import Foundation
import GRDB

/// Repository for CRUD operations on YearSummary records
class YearSummaryRepository {
    private let dbService: DatabaseService

    init(dbService: DatabaseService = .shared) {
        self.dbService = dbService
    }

    /// Save year summary to the database
    func save(_ summary: YearSummary) throws {
        try dbService.getQueue().write { db in
            let topEventsJSON = try JSONEncoder().encode(summary.topEvents)
            let sourceSpansJSON = try JSONEncoder().encode(summary.sourceSpans)

            // Check if summary already exists for this year
            let existingId = try String.fetchOne(
                db,
                sql: "SELECT id FROM year_summaries WHERE year = ?",
                arguments: [summary.year]
            )

            if let existingId = existingId {
                // Update existing record
                try db.execute(
                    sql: """
                    UPDATE year_summaries SET
                        summary_text = ?,
                        happiness_avg = ?,
                        happiness_ci_lower = ?,
                        happiness_ci_upper = ?,
                        top_events_json = ?,
                        source_spans_json = ?,
                        generated_at = ?
                    WHERE id = ?
                    """,
                    arguments: [
                        summary.summaryText,
                        summary.happinessAvg,
                        summary.happinessConfidenceInterval.lower,
                        summary.happinessConfidenceInterval.upper,
                        String(data: topEventsJSON, encoding: .utf8),
                        String(data: sourceSpansJSON, encoding: .utf8),
                        summary.generatedAt,
                        existingId
                    ]
                )
            } else {
                // Insert new record
                try db.execute(
                    sql: """
                    INSERT INTO year_summaries (
                        id, year, summary_text, happiness_avg,
                        happiness_ci_lower, happiness_ci_upper,
                        top_events_json, source_spans_json, generated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        summary.id.uuidString,
                        summary.year,
                        summary.summaryText,
                        summary.happinessAvg,
                        summary.happinessConfidenceInterval.lower,
                        summary.happinessConfidenceInterval.upper,
                        String(data: topEventsJSON, encoding: .utf8),
                        String(data: sourceSpansJSON, encoding: .utf8),
                        summary.generatedAt
                    ]
                )
            }
        }
    }

    /// Get summary for a specific year
    func get(year: Int) throws -> YearSummary? {
        try dbService.getQueue().read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM year_summaries WHERE year = ?",
                arguments: [year]
            ) else {
                return nil
            }
            return try rowToSummary(row)
        }
    }

    /// Get all year summaries
    func getAll() throws -> [YearSummary] {
        try dbService.getQueue().read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM year_summaries ORDER BY year DESC"
            )
            return try rows.map { try rowToSummary($0) }
        }
    }

    // MARK: - Private Helpers

    private func rowToSummary(_ row: Row) throws -> YearSummary {
        let id: String = row["id"]
        let year: Int = row["year"]
        let summaryText: String = row["summary_text"]
        let happinessAvg: Double = row["happiness_avg"]
        let happinessCILower: Double = row["happiness_ci_lower"]
        let happinessCIUpper: Double = row["happiness_ci_upper"]
        let generatedAt: Date = row["generated_at"]

        let topEventsJSONStr: String = row["top_events_json"]
        let sourceSpansJSONStr: String = row["source_spans_json"]

        guard let topEventsData = topEventsJSONStr.data(using: .utf8),
              let sourceSpansData = sourceSpansJSONStr.data(using: .utf8) else {
            throw LifeOSDatabaseError.invalidJSON
        }

        let topEvents = try JSONDecoder().decode([DetectedEvent].self, from: topEventsData)
        let sourceSpans = try JSONDecoder().decode([SourceSpan].self, from: sourceSpansData)

        return YearSummary(
            id: UUID(uuidString: id) ?? UUID(),
            year: year,
            summaryText: summaryText,
            happinessAvg: happinessAvg,
            happinessConfidenceInterval: (happinessCILower, happinessCIUpper),
            topEvents: topEvents,
            sourceSpans: sourceSpans,
            generatedAt: generatedAt
        )
    }
}
