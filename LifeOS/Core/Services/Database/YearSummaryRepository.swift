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

            try db.execute(
                sql: """
                INSERT INTO year_summaries (
                    year, summary_text, happiness_avg,
                    happiness_ci_lower, happiness_ci_upper,
                    top_events_json, source_spans_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(year) DO UPDATE SET
                    summary_text = excluded.summary_text,
                    happiness_avg = excluded.happiness_avg,
                    happiness_ci_lower = excluded.happiness_ci_lower,
                    happiness_ci_upper = excluded.happiness_ci_upper,
                    top_events_json = excluded.top_events_json,
                    source_spans_json = excluded.source_spans_json
                """,
                arguments: [
                    summary.year,
                    summary.summaryText,
                    summary.happinessAvg,
                    summary.happinessCI.0,
                    summary.happinessCI.1,
                    String(data: topEventsJSON, encoding: .utf8),
                    String(data: sourceSpansJSON, encoding: .utf8)
                ]
            )
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
        let year: Int = row["year"]
        let summaryText: String = row["summary_text"]
        let happinessAvg: Double = row["happiness_avg"]
        let happinessCILower: Double = row["happiness_ci_lower"]
        let happinessCIUpper: Double = row["happiness_ci_upper"]

        let topEventsJSONStr: String = row["top_events_json"]
        let sourceSpansJSONStr: String = row["source_spans_json"]

        guard let topEventsData = topEventsJSONStr.data(using: .utf8),
              let sourceSpansData = sourceSpansJSONStr.data(using: .utf8) else {
            throw DatabaseError.invalidJSON
        }

        let topEvents = try JSONDecoder().decode([DetectedEvent].self, from: topEventsData)
        let sourceSpans = try JSONDecoder().decode([SourceSpan].self, from: sourceSpansData)

        return YearSummary(
            year: year,
            summaryText: summaryText,
            happinessAvg: happinessAvg,
            happinessCI: (happinessCILower, happinessCIUpper),
            topEvents: topEvents,
            sourceSpans: sourceSpans
        )
    }
}
