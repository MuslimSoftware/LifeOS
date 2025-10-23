import Foundation
import GRDB

/// Repository for CRUD operations on MonthSummary records
class MonthSummaryRepository {
    private let dbService: DatabaseService

    init(dbService: DatabaseService = .shared) {
        self.dbService = dbService
    }

    /// Save month summary to the database
    func save(_ summary: MonthSummary) throws {
        try dbService.getQueue().write { db in
            let topEventsJSON = try JSONEncoder().encode(summary.topEvents)
            let sourceSpansJSON = try JSONEncoder().encode(summary.sourceSpans)

            try db.execute(
                sql: """
                INSERT INTO month_summaries (
                    year, month, summary_text, happiness_avg,
                    happiness_ci_lower, happiness_ci_upper,
                    drivers_positive, drivers_negative,
                    top_events_json, source_spans_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(year, month) DO UPDATE SET
                    summary_text = excluded.summary_text,
                    happiness_avg = excluded.happiness_avg,
                    happiness_ci_lower = excluded.happiness_ci_lower,
                    happiness_ci_upper = excluded.happiness_ci_upper,
                    drivers_positive = excluded.drivers_positive,
                    drivers_negative = excluded.drivers_negative,
                    top_events_json = excluded.top_events_json,
                    source_spans_json = excluded.source_spans_json
                """,
                arguments: [
                    summary.year,
                    summary.month,
                    summary.summaryText,
                    summary.happinessAvg,
                    summary.happinessCI.0,
                    summary.happinessCI.1,
                    summary.driversPositive.joined(separator: "|||"),
                    summary.driversNegative.joined(separator: "|||"),
                    String(data: topEventsJSON, encoding: .utf8),
                    String(data: sourceSpansJSON, encoding: .utf8)
                ]
            )
        }
    }

    /// Get summary for a specific month
    func get(year: Int, month: Int) throws -> MonthSummary? {
        try dbService.getQueue().read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM month_summaries WHERE year = ? AND month = ?",
                arguments: [year, month]
            ) else {
                return nil
            }
            return try rowToSummary(row)
        }
    }

    /// Get all summaries for a year
    func getAllForYear(_ year: Int) throws -> [MonthSummary] {
        try dbService.getQueue().read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM month_summaries WHERE year = ? ORDER BY month",
                arguments: [year]
            )
            return try rows.map { try rowToSummary($0) }
        }
    }

    /// Get all month summaries
    func getAll() throws -> [MonthSummary] {
        try dbService.getQueue().read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM month_summaries ORDER BY year DESC, month DESC"
            )
            return try rows.map { try rowToSummary($0) }
        }
    }

    // MARK: - Private Helpers

    private func rowToSummary(_ row: Row) throws -> MonthSummary {
        let year: Int = row["year"]
        let month: Int = row["month"]
        let summaryText: String = row["summary_text"]
        let happinessAvg: Double = row["happiness_avg"]
        let happinessCILower: Double = row["happiness_ci_lower"]
        let happinessCIUpper: Double = row["happiness_ci_upper"]

        let driversPositiveStr: String = row["drivers_positive"]
        let driversNegativeStr: String = row["drivers_negative"]
        let driversPositive = driversPositiveStr.split(separator: "|||").map(String.init)
        let driversNegative = driversNegativeStr.split(separator: "|||").map(String.init)

        let topEventsJSONStr: String = row["top_events_json"]
        let sourceSpansJSONStr: String = row["source_spans_json"]

        guard let topEventsData = topEventsJSONStr.data(using: .utf8),
              let sourceSpansData = sourceSpansJSONStr.data(using: .utf8) else {
            throw DatabaseError.invalidJSON
        }

        let topEvents = try JSONDecoder().decode([DetectedEvent].self, from: topEventsData)
        let sourceSpans = try JSONDecoder().decode([SourceSpan].self, from: sourceSpansData)

        return MonthSummary(
            year: year,
            month: month,
            summaryText: summaryText,
            happinessAvg: happinessAvg,
            happinessCI: (happinessCILower, happinessCIUpper),
            driversPositive: driversPositive,
            driversNegative: driversNegative,
            topEvents: topEvents,
            sourceSpans: sourceSpans
        )
    }
}

enum DatabaseError: Error {
    case invalidJSON
}
