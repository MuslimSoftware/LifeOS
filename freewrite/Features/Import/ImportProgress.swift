import Foundation

enum ImportProgress {
    case started(total: Int)
    case processing(current: Int, total: Int, filename: String)
    case completed(entry: ImportedEntry, current: Int, total: Int)
    case failed(error: Error, filename: String, current: Int, total: Int)
    case finished(successful: Int, failed: Int)
    case cancelled(processed: Int, total: Int)
}

typealias ProgressCallback = @MainActor (ImportProgress) async -> Void
