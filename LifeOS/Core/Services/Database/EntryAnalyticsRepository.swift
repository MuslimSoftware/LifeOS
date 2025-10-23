import Foundation
import GRDB

/// Repository for CRUD operations on EntryAnalytics records
class EntryAnalyticsRepository {
    private let dbService: DatabaseService

    init(dbService: DatabaseService = .shared) {
        self.dbService = dbService
    }

    /// Save entry analytics to the database
    func save(_ analytics: EntryAnalytics) throws {
        try dbService.getQueue().write { db in
            let emotionsJSON = try JSONEncoder().encode(analytics.emotions)
            let eventsJSON = try JSONEncoder().encode(analytics.events)

            try db.execute(
                sql: """
                INSERT INTO entry_analytics (
                    id, entry_id, date, happiness_score, valence, arousal,
                    emotions_json, events_json, confidence, analyzed_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(entry_id) DO UPDATE SET
                    happiness_score = excluded.happiness_score,
                    valence = excluded.valence,
                    arousal = excluded.arousal,
                    emotions_json = excluded.emotions_json,
                    events_json = excluded.events_json,
                    confidence = excluded.confidence,
                    analyzed_at = excluded.analyzed_at
                """,
                arguments: [
                    analytics.id.uuidString,
                    analytics.entryId.uuidString,
                    analytics.date,
                    analytics.happinessScore,
                    analytics.valence,
                    analytics.arousal,
                    String(data: emotionsJSON, encoding: .utf8),
                    String(data: eventsJSON, encoding: .utf8),
                    analytics.confidence,
                    analytics.analyzedAt
                ]
            )
        }
    }

    /// Get analytics for a specific entry
    func get(forEntryId entryId: UUID) throws -> EntryAnalytics? {
        try dbService.getQueue().read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM entry_analytics WHERE entry_id = ?",
                arguments: [entryId.uuidString]
            ) else {
                return nil
            }
            return try rowToAnalytics(row)
        }
    }

    /// Get analytics within a date range
    func getAnalytics(from startDate: Date, to endDate: Date) throws -> [EntryAnalytics] {
        try dbService.getQueue().read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM entry_analytics WHERE date BETWEEN ? AND ? ORDER BY date",
                arguments: [startDate, endDate]
            )
            return try rows.map { try rowToAnalytics($0) }
        }
    }

    /// Get all analytics
    func getAllAnalytics() throws -> [EntryAnalytics] {
        try dbService.getQueue().read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM entry_analytics ORDER BY date DESC"
            )
            return try rows.map { try rowToAnalytics($0) }
        }
    }

    /// Delete analytics for a specific entry
    func delete(forEntryId entryId: UUID) throws {
        try dbService.getQueue().write { db in
            try db.execute(
                sql: "DELETE FROM entry_analytics WHERE entry_id = ?",
                arguments: [entryId.uuidString]
            )
        }
    }

    // MARK: - Private Helpers

    private func rowToAnalytics(_ row: Row) throws -> EntryAnalytics {
        guard let id = UUID(uuidString: row["id"]),
              let entryId = UUID(uuidString: row["entry_id"]) else {
            throw DatabaseError.queryFailed("Invalid UUID in analytics row")
        }

        let emotionsData = (row["emotions_json"] as String).data(using: .utf8)!
        let eventsData = (row["events_json"] as String).data(using: .utf8)!

        let emotions = try JSONDecoder().decode(EmotionScores.self, from: emotionsData)
        let events = try JSONDecoder().decode([DetectedEvent].self, from: eventsData)

        return EntryAnalytics(
            id: id,
            entryId: entryId,
            date: row["date"],
            happinessScore: row["happiness_score"],
            valence: row["valence"],
            arousal: row["arousal"],
            emotions: emotions,
            events: events,
            confidence: row["confidence"],
            analyzedAt: row["analyzed_at"]
        )
    }
}
