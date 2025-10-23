//
//  SummarizationTask.swift
//  LifeOS
//
//  Created by Claude on 10/23/25.
//

import Foundation

/// Background operation for regenerating monthly and yearly summaries
/// Wraps SummarizationService with progress reporting and cancellation support
class SummarizationTask: Operation, @unchecked Sendable {

    // MARK: - Properties

    private let summarizationService: SummarizationService
    private let progressHandler: ((String) -> Void)?

    /// Foundation Progress object for KVO-compatible progress reporting
    let taskProgress: Progress

    private var task: Task<Void, Error>?

    // MARK: - Initialization

    /// Create a new summarization task
    /// - Parameters:
    ///   - summarizationService: The summarization service to use
    ///   - progressHandler: Optional callback for progress updates (status message)
    init(
        summarizationService: SummarizationService,
        progressHandler: ((String) -> Void)? = nil
    ) {
        self.summarizationService = summarizationService
        self.progressHandler = progressHandler
        self.taskProgress = Progress(totalUnitCount: 100)
        super.init()

        self.name = "Summarization"
        self.qualityOfService = .utility
    }

    // MARK: - Operation Lifecycle

    override func main() {
        guard !isCancelled else {
            print("⚠️ SummarizationTask cancelled before start")
            return
        }

        print("🚀 Starting SummarizationTask")
        taskProgress.completedUnitCount = 0

        // Create a semaphore to wait for async task
        let semaphore = DispatchSemaphore(value: 0)
        var taskError: Error?

        task = Task {
            do {
                // Get all analytics to determine what to summarize
                let dbService = DatabaseService.shared
                let analyticsRepo = EntryAnalyticsRepository(dbService: dbService)
                let allAnalytics = try analyticsRepo.getAllAnalytics()

                guard !allAnalytics.isEmpty else {
                    self.progressHandler?("No analytics data found")
                    semaphore.signal()
                    return
                }

                // Group by year/month
                var yearMonths: Set<YearMonth> = []
                for analytics in allAnalytics {
                    let calendar = Calendar.current
                    let year = calendar.component(.year, from: analytics.date)
                    let month = calendar.component(.month, from: analytics.date)
                    yearMonths.insert(YearMonth(year: year, month: month))
                }

                let sortedYearMonths = yearMonths.sorted { lhs, rhs in
                    if lhs.year != rhs.year {
                        return lhs.year < rhs.year
                    }
                    return lhs.month < rhs.month
                }

                let totalMonths = sortedYearMonths.count
                let years = Set(sortedYearMonths.map { $0.year }).sorted()
                let totalYears = years.count
                let totalUnits = totalMonths + totalYears

                self.taskProgress.totalUnitCount = Int64(totalUnits)
                var completed = 0

                // Summarize months
                self.progressHandler?("Summarizing \(totalMonths) months...")
                for yearMonth in sortedYearMonths {
                    guard !self.isCancelled else {
                        throw CancellationError()
                    }

                    self.progressHandler?("Summarizing \(yearMonth.year)-\(String(format: "%02d", yearMonth.month))...")

                    _ = try await self.summarizationService.summarizeMonth(
                        year: yearMonth.year,
                        month: yearMonth.month
                    )

                    completed += 1
                    self.taskProgress.completedUnitCount = Int64(completed)

                    // Small delay to avoid rate limiting
                    try await Task.sleep(nanoseconds: 500_000_000)
                }

                // Summarize years
                self.progressHandler?("Summarizing \(totalYears) years...")
                for year in years {
                    guard !self.isCancelled else {
                        throw CancellationError()
                    }

                    self.progressHandler?("Summarizing year \(year)...")

                    _ = try await self.summarizationService.summarizeYear(year: year)

                    completed += 1
                    self.taskProgress.completedUnitCount = Int64(completed)

                    try await Task.sleep(nanoseconds: 500_000_000)
                }

                print("✅ SummarizationTask completed successfully")
            } catch is CancellationError {
                print("⚠️ SummarizationTask cancelled by user")
            } catch {
                print("❌ SummarizationTask failed: \(error)")
                taskError = error
            }

            semaphore.signal()
        }

        // Wait for task to complete (or be cancelled)
        semaphore.wait()

        // Mark progress as complete or failed
        if let error = taskError {
            taskProgress.cancel()
            print("❌ Task completed with error: \(error.localizedDescription)")
        } else if isCancelled {
            taskProgress.cancel()
            print("⚠️ Task was cancelled")
        } else {
            taskProgress.completedUnitCount = taskProgress.totalUnitCount
            print("✅ Task progress: 100%")
        }
    }

    override func cancel() {
        super.cancel()
        task?.cancel()
        taskProgress.cancel()
        print("🛑 SummarizationTask cancelled")
    }
}

// MARK: - Helper Types

private struct YearMonth: Hashable {
    let year: Int
    let month: Int
}
