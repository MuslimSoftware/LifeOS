//
//  BackgroundTaskService.swift
//  LifeOS
//
//  Created by Claude on 10/23/25.
//

import Foundation

/// Manages background task execution with priority queuing
/// Singleton service for coordinating long-running analytics operations
@Observable
class BackgroundTaskService {

    // MARK: - Singleton

    static let shared = BackgroundTaskService()

    // MARK: - Properties

    private let operationQueue: OperationQueue

    /// Number of currently active tasks
    var activeTaskCount: Int {
        operationQueue.operationCount
    }

    /// All pending and active operations
    var allOperations: [Operation] {
        operationQueue.operations
    }

    // MARK: - Initialization

    private init() {
        operationQueue = OperationQueue()
        operationQueue.name = "com.lifeos.background.analytics"
        operationQueue.maxConcurrentOperationCount = 1 // Sequential processing to avoid rate limits
        operationQueue.qualityOfService = .utility
    }

    // MARK: - Task Management

    /// Add a task to the background queue
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - priority: Priority level (default: normal)
    func addTask(_ operation: Operation, priority: Operation.QueuePriority = .normal) {
        operation.queuePriority = priority
        operationQueue.addOperation(operation)
        print("🎯 Added task to background queue: \(type(of: operation))")
        print("   Active tasks: \(activeTaskCount)")
    }

    /// Add multiple tasks to the queue
    /// - Parameters:
    ///   - operations: Array of operations to execute
    ///   - waitUntilFinished: Whether to block until all operations complete
    func addTasks(_ operations: [Operation], waitUntilFinished: Bool = false) {
        operationQueue.addOperations(operations, waitUntilFinished: waitUntilFinished)
        print("🎯 Added \(operations.count) tasks to background queue")
        print("   Active tasks: \(activeTaskCount)")
    }

    /// Cancel all pending and active tasks
    func cancelAllTasks() {
        operationQueue.cancelAllOperations()
        print("🛑 Cancelled all background tasks")
    }

    /// Cancel tasks of a specific type
    /// - Parameter type: The operation class type to cancel
    func cancelTasks<T: Operation>(ofType type: T.Type) {
        let operations = operationQueue.operations.filter { $0 is T }
        operations.forEach { $0.cancel() }
        print("🛑 Cancelled \(operations.count) tasks of type \(type)")
    }

    /// Wait for all current tasks to complete
    func waitForAllTasks() {
        operationQueue.waitUntilAllOperationsAreFinished()
    }

    /// Pause task execution
    func pause() {
        operationQueue.isSuspended = true
        print("⏸️  Background task queue paused")
    }

    /// Resume task execution
    func resume() {
        operationQueue.isSuspended = false
        print("▶️  Background task queue resumed")
    }

    /// Check if queue is currently suspended
    var isPaused: Bool {
        operationQueue.isSuspended
    }

}
