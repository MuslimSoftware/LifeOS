//
//  AnalyticsStorageStats.swift
//  LifeOS
//
//  Created by Claude on 10/23/25.
//

import Foundation

/// Storage and analytics statistics
/// Used by Settings view to display analytics database status
struct AnalyticsStorageStats: Codable {

    /// Total number of journal entries in the system
    let totalEntries: Int

    /// Number of entries that have been analyzed
    let analyzedEntries: Int

    /// Database file size in bytes
    let databaseSizeBytes: Int64

    /// Date when analytics were last processed
    let lastProcessedDate: Date?

    /// Computed percentage of entries analyzed
    var percentageAnalyzed: Int {
        guard totalEntries > 0 else { return 0 }
        return Int((Double(analyzedEntries) / Double(totalEntries)) * 100)
    }

    /// Database size formatted as human-readable string
    var databaseSizeFormatted: String {
        let sizeInMB = Double(databaseSizeBytes) / 1_048_576
        if sizeInMB >= 1000 {
            return String(format: "%.2f GB", sizeInMB / 1024)
        } else {
            return String(format: "%.2f MB", sizeInMB)
        }
    }

    /// Whether all entries have been analyzed
    var isFullyProcessed: Bool {
        analyzedEntries >= totalEntries && totalEntries > 0
    }

    /// Number of entries remaining to be processed
    var remainingEntries: Int {
        max(0, totalEntries - analyzedEntries)
    }
}

// MARK: - Stats Loading

extension AnalyticsStorageStats {

    /// Load current analytics storage statistics
    /// - Parameters:
    ///   - fileManagerService: Service to load entries
    ///   - databaseService: Database service to query analytics
    /// - Returns: Current storage stats
    static func load(
        fileManagerService: FileManagerService,
        databaseService: DatabaseService
    ) throws -> AnalyticsStorageStats {

        // Get total entries count
        let allEntries = fileManagerService.loadExistingEntries()
        let totalEntries = allEntries.count

        // Get analyzed entries count
        try databaseService.initialize()
        let analyticsRepo = EntryAnalyticsRepository(dbService: databaseService)
        let allAnalytics = try analyticsRepo.getAllAnalytics()
        let analyzedEntries = allAnalytics.count

        // Get last processed date (most recent analysis)
        let lastProcessedDate = allAnalytics.first?.analyzedAt

        // Get database file size
        let dbURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("LifeOS/analytics.db")

        var databaseSizeBytes: Int64 = 0
        if let attributes = try? FileManager.default.attributesOfItem(atPath: dbURL.path),
           let fileSize = attributes[.size] as? Int64 {
            databaseSizeBytes = fileSize
        }

        return AnalyticsStorageStats(
            totalEntries: totalEntries,
            analyzedEntries: analyzedEntries,
            databaseSizeBytes: databaseSizeBytes,
            lastProcessedDate: lastProcessedDate
        )
    }
}
