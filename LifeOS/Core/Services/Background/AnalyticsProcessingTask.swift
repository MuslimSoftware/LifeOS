//
//  AnalyticsProcessingTask.swift
//  LifeOS
//
//  Created by Claude on 10/23/25.
//

import Foundation

/// Background operation for processing journal entries through analytics pipeline
/// Wraps AnalyticsPipelineService with progress reporting and cancellation support
class AnalyticsProcessingTask: Operation, @unchecked Sendable {

    // MARK: - Properties

    private let pipelineService: AnalyticsPipelineService
    private let skipExisting: Bool
    private let progressHandler: ((Int, Int) -> Void)?

    /// Foundation Progress object for KVO-compatible progress reporting
    let taskProgress: Progress

    private var task: Task<Void, Error>?

    // MARK: - Initialization

    /// Create a new analytics processing task
    /// - Parameters:
    ///   - pipelineService: The pipeline service to use for processing
    ///   - skipExisting: Whether to skip already-processed entries (default: true)
    ///   - progressHandler: Optional callback for progress updates (current, total)
    init(
        pipelineService: AnalyticsPipelineService,
        skipExisting: Bool = true,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) {
        self.pipelineService = pipelineService
        self.skipExisting = skipExisting
        self.progressHandler = progressHandler
        self.taskProgress = Progress(totalUnitCount: 100)
        super.init()

        self.name = "AnalyticsProcessing"
        self.qualityOfService = .utility
    }

    // MARK: - Operation Lifecycle

    override func main() {
        guard !isCancelled else {
            print("⚠️ AnalyticsProcessingTask cancelled before start")
            return
        }

        print("🚀 Starting AnalyticsProcessingTask")
        taskProgress.completedUnitCount = 0

        // Create a semaphore to wait for async task
        let semaphore = DispatchSemaphore(value: 0)
        var taskError: Error?

        task = Task {
            do {
                try await pipelineService.processAllEntries(skipExisting: skipExisting) { current, total in
                    guard !self.isCancelled else { return }

                    // Update Foundation Progress
                    self.taskProgress.totalUnitCount = Int64(total)
                    self.taskProgress.completedUnitCount = Int64(current)

                    // Call custom progress handler
                    self.progressHandler?(current, total)
                }

                print("✅ AnalyticsProcessingTask completed successfully")
            } catch is CancellationError {
                print("⚠️ AnalyticsProcessingTask cancelled by user")
            } catch {
                print("❌ AnalyticsProcessingTask failed: \(error)")
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
        print("🛑 AnalyticsProcessingTask cancelled")
    }
}
