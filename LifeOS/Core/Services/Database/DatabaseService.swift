import Foundation
import GRDB

/// Errors that can occur during database operations
enum LifeOSDatabaseError: Error, LocalizedError {
    case initializationFailed(String)
    case migrationFailed(String)
    case queryFailed(String)
    case notFound
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return "Database initialization failed: \(message)"
        case .migrationFailed(let message):
            return "Database migration failed: \(message)"
        case .queryFailed(let message):
            return "Database query failed: \(message)"
        case .notFound:
            return "Record not found"
        case .invalidJSON:
            return "Invalid JSON data in database"
        }
    }
}

/// Central database service for analytics data
/// Manages SQLite connection and provides data access
class DatabaseService {
    static let shared = DatabaseService()

    private var dbQueue: DatabaseQueue?
    private let fileManager = FileManager.default

    /// Database file location (same directory as journal files for portability)
    private var databaseURL: URL {
        let documentsDirectory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("LifeOS")

        return documentsDirectory.appendingPathComponent("analytics.db")
    }

    private init() {}

    /// Initialize the database and run migrations
    func initialize() throws {
        // Ensure directory exists
        let directory = databaseURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        do {
            // Create database queue
            dbQueue = try DatabaseQueue(path: databaseURL.path)

            // Run migrations
            try migrate()

            print("✅ Database initialized at: \(databaseURL.path)")
        } catch {
            throw LifeOSDatabaseError.initializationFailed(error.localizedDescription)
        }
    }

    /// Get the database queue for custom queries
    func getQueue() throws -> DatabaseQueue {
        guard let queue = dbQueue else {
            throw LifeOSDatabaseError.initializationFailed("Database not initialized")
        }
        return queue
    }

    /// Run database migrations
    private func migrate() throws {
        guard let dbQueue = dbQueue else {
            throw LifeOSDatabaseError.migrationFailed("Database queue not initialized")
        }

        var migrator = DatabaseMigrator()

        // Migration v1: Create initial schema
        migrator.registerMigration("v1_initial_schema") { db in
            // Chunks table - stores text segments with embeddings
            try db.create(table: "chunks") { t in
                t.column("id", .text).primaryKey()
                t.column("entry_id", .text).notNull()
                t.column("text", .text).notNull()
                t.column("embedding", .blob)  // Float array as binary
                t.column("start_char", .integer).notNull()
                t.column("end_char", .integer).notNull()
                t.column("date", .datetime).notNull()
                t.column("token_count", .integer).notNull()
                t.column("created_at", .datetime).notNull()
            }
            try db.create(index: "idx_chunks_entry_id", on: "chunks", columns: ["entry_id"])
            try db.create(index: "idx_chunks_date", on: "chunks", columns: ["date"])

            // Entry analytics table
            try db.create(table: "entry_analytics") { t in
                t.column("id", .text).primaryKey()
                t.column("entry_id", .text).notNull().unique()
                t.column("date", .datetime).notNull()
                t.column("happiness_score", .double).notNull()
                t.column("valence", .double).notNull()
                t.column("arousal", .double).notNull()
                t.column("emotions_json", .text).notNull()  // JSON-encoded EmotionScores
                t.column("events_json", .text).notNull()    // JSON-encoded [DetectedEvent]
                t.column("confidence", .double).notNull()
                t.column("analyzed_at", .datetime).notNull()
            }
            try db.create(index: "idx_entry_analytics_date", on: "entry_analytics", columns: ["date"])

            // Month summaries table
            try db.create(table: "month_summaries") { t in
                t.column("id", .text).primaryKey()
                t.column("year", .integer).notNull()
                t.column("month", .integer).notNull()
                t.column("summary_text", .text).notNull()
                t.column("key_topics_json", .text).notNull()
                t.column("happiness_avg", .double).notNull()
                t.column("happiness_ci_lower", .double).notNull()
                t.column("happiness_ci_upper", .double).notNull()
                t.column("drivers_positive_json", .text).notNull()
                t.column("drivers_negative_json", .text).notNull()
                t.column("top_events_json", .text).notNull()
                t.column("source_spans_json", .text).notNull()
                t.column("generated_at", .datetime).notNull()
            }
            try db.create(index: "idx_month_summaries_year_month", on: "month_summaries", columns: ["year", "month"])

            // Year summaries table
            try db.create(table: "year_summaries") { t in
                t.column("id", .text).primaryKey()
                t.column("year", .integer).notNull().unique()
                t.column("summary_text", .text).notNull()
                t.column("happiness_avg", .double).notNull()
                t.column("happiness_ci_lower", .double).notNull()
                t.column("happiness_ci_upper", .double).notNull()
                t.column("top_events_json", .text).notNull()
                t.column("source_spans_json", .text).notNull()
                t.column("generated_at", .datetime).notNull()
            }

            // Time series table
            try db.create(table: "time_series") { t in
                t.column("id", .text).primaryKey()
                t.column("date", .datetime).notNull()
                t.column("metric", .text).notNull()
                t.column("value", .double).notNull()
                t.column("confidence", .double).notNull()
            }
            try db.create(index: "idx_time_series_date_metric", on: "time_series", columns: ["date", "metric"])

            // Life events table
            try db.create(table: "life_events") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("start_date", .datetime).notNull()
                t.column("end_date", .datetime)
                t.column("description", .text).notNull()
                t.column("categories_json", .text).notNull()
                t.column("salience", .double).notNull()
                t.column("sentiment", .double).notNull()
                t.column("source_spans_json", .text).notNull()
            }
            try db.create(index: "idx_life_events_start_date", on: "life_events", columns: ["start_date"])
        }

        // Migration v2: Add FTS5 support for hybrid search
        migrator.registerMigration("v2_fts_support") { db in
            // Create FTS5 virtual table for full-text search
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts
                USING fts5(
                    text,
                    content='chunks',
                    content_rowid='rowid',
                    tokenize='porter unicode61'
                );
            """)

            // Populate FTS table with existing chunks
            try db.execute(sql: """
                INSERT INTO chunks_fts(rowid, text)
                SELECT rowid, text FROM chunks;
            """)

            // Create triggers to keep FTS in sync with chunks table
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
                    INSERT INTO chunks_fts(rowid, text) VALUES (new.rowid, new.text);
                END;
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
                    DELETE FROM chunks_fts WHERE rowid = old.rowid;
                END;
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS chunks_au AFTER UPDATE ON chunks BEGIN
                    UPDATE chunks_fts SET text = new.text WHERE rowid = new.rowid;
                END;
            """)

            print("✅ FTS5 virtual table and triggers created")
        }

        do {
            try migrator.migrate(dbQueue)
            print("✅ Database migrations completed")
        } catch {
            throw LifeOSDatabaseError.migrationFailed(error.localizedDescription)
        }
    }

    /// Clear all analytics data (useful for reprocessing)
    func clearAllData() throws {
        try dbQueue?.write { db in
            try db.execute(sql: "DELETE FROM chunks")
            try db.execute(sql: "DELETE FROM entry_analytics")
            try db.execute(sql: "DELETE FROM month_summaries")
            try db.execute(sql: "DELETE FROM year_summaries")
            try db.execute(sql: "DELETE FROM time_series")
            try db.execute(sql: "DELETE FROM life_events")
        }
        print("🗑️ Cleared all analytics data")
    }
}
