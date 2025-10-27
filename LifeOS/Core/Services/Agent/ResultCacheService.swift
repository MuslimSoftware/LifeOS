import Foundation

/// Shared cache for storing large tool results to avoid token overflow
/// Used by AgentKernel to cache retrieve results and by AnalyzeTool to resolve them
class ResultCacheService {
    static let shared = ResultCacheService()

    private var cache: [String: Any] = [:]
    private var counter = 0
    private let lock = NSLock()

    private init() {}

    /// Store a result and get a unique ID
    /// - Parameter result: The result to cache
    /// - Returns: A unique result ID that can be used to retrieve it later
    func store(result: Any) -> String {
        lock.lock()
        defer { lock.unlock() }

        counter += 1
        let resultId = "retrieve_\(counter)"
        cache[resultId] = result

        return resultId
    }

    /// Retrieve a cached result by ID
    /// - Parameter id: The result ID
    /// - Returns: The cached result, or nil if not found
    func get(id: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }

        return cache[id]
    }

    /// Clear all cached results
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
        counter = 0
    }

    /// Clear a specific cached result
    /// - Parameter id: The result ID to clear
    func clear(id: String) {
        lock.lock()
        defer { lock.unlock() }

        cache.removeValue(forKey: id)
    }
}
