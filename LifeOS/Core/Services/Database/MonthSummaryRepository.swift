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
            let keyTopicsJSON = try JSONEncoder().encode(summary.keyTopics)
            let driversPositiveJSON = try JSONEncoder().encode(summary.driversPositive)
            let driversNegativeJSON = try JSONEncoder().encode(summary.driversNegative)
            let topEventsJSON = try JSONEncoder().encode(summary.topEvents)
            let sourceSpansJSON = try JSONEncoder().encode(summary.sourceSpans)

            // Check if summary already exists for this year/month
            let existingId = try String.fetchOne(
                db,
                sql: "SELECT id FROM month_summaries WHERE year = ? AND month = ?",
                arguments: [summary.year, summary.month]
            )

            if let existingId = existingId {
                // Update existing record
                try db.execute(
                    sql: """
                    UPDATE month_summaries SET
                        summary_text = ?,
                        key_topics_json = ?,
                        happiness_avg = ?,
                        happiness_ci_lower = ?,
                        happiness_ci_upper = ?,
                        drivers_positive_json = ?,
                        drivers_negative_json = ?,
                        top_events_json = ?,
                        source_spans_json = ?,
                        generated_at = ?
                    WHERE id = ?
                    """,
                    arguments: [
                        summary.summaryText,
                        String(data: keyTopicsJSON, encoding: .utf8),
                        summary.happinessAvg,
                        summary.happinessConfidenceInterval.lower,
                        summary.happinessConfidenceInterval.upper,
                        String(data: driversPositiveJSON, encoding: .utf8),
                        String(data: driversNegativeJSON, encoding: .utf8),
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
                    INSERT INTO month_summaries (
                        id, year, month, summary_text, key_topics_json,
                        happiness_avg, happiness_ci_lower, happiness_ci_upper,
                        drivers_positive_json, drivers_negative_json,
                        top_events_json, source_spans_json, generated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    summary.id.uuidString,
                    summary.year,
                    summary.month,
                    summary.summaryText,
                    String(data: keyTopicsJSON, encoding: .utf8),
                    summary.happinessAvg,
                    summary.happinessConfidenceInterval.lower,
                    summary.happinessConfidenceInterval.upper,
                    String(data: driversPositiveJSON, encoding: .utf8),
                    String(data: driversNegativeJSON, encoding: .utf8),
                    String(data: topEventsJSON, encoding: .utf8),
                    String(data: sourceSpansJSON, encoding: .utf8),
                    summary.generatedAt
                ]
                )
            }
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
        let id: String = row["id"]
        let year: Int = row["year"]
        let month: Int = row["month"]
        let summaryText: String = row["summary_text"]
        let happinessAvg: Double = row["happiness_avg"]
        let happinessCILower: Double = row["happiness_ci_lower"]
        let happinessCIUpper: Double = row["happiness_ci_upper"]
        let generatedAt: Date = row["generated_at"]

        let keyTopicsJSONStr: String = row["key_topics_json"]
        let driversPositiveJSONStr: String = row["drivers_positive_json"]
        let driversNegativeJSONStr: String = row["drivers_negative_json"]
        let topEventsJSONStr: String = row["top_events_json"]
        let sourceSpansJSONStr: String = row["source_spans_json"]

        guard let keyTopicsData = keyTopicsJSONStr.data(using: .utf8),
              let driversPositiveData = driversPositiveJSONStr.data(using: .utf8),
              let driversNegativeData = driversNegativeJSONStr.data(using: .utf8),
              let topEventsData = topEventsJSONStr.data(using: .utf8),
              let sourceSpansData = sourceSpansJSONStr.data(using: .utf8) else {
            throw LifeOSDatabaseError.invalidJSON
        }

        let keyTopics = try JSONDecoder().decode([String].self, from: keyTopicsData)
        let driversPositive = try JSONDecoder().decode([String].self, from: driversPositiveData)
        let driversNegative = try JSONDecoder().decode([String].self, from: driversNegativeData)
        let topEvents = try JSONDecoder().decode([DetectedEvent].self, from: topEventsData)
        let sourceSpans = try JSONDecoder().decode([SourceSpan].self, from: sourceSpansData)

        return MonthSummary(
            id: UUID(uuidString: id) ?? UUID(),
            year: year,
            month: month,
            summaryText: summaryText,
            keyTopics: keyTopics,
            happinessAvg: happinessAvg,
            happinessConfidenceInterval: (happinessCILower, happinessCIUpper),
            driversPositive: driversPositive,
            driversNegative: driversNegative,
            topEvents: topEvents,
            sourceSpans: sourceSpans,
            generatedAt: generatedAt
        )
    }
}

enum MonthSummaryError: Error {
    case invalidJSON
}
