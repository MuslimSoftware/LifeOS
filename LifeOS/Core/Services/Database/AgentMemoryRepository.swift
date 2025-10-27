import Foundation
import GRDB

/// Repository for managing agent memory persistence
class AgentMemoryRepository {
    private let dbService: DatabaseService

    init(dbService: DatabaseService) {
        self.dbService = dbService
    }

    // MARK: - Create / Update

    /// Save a memory to the database
    /// - Parameter memory: The memory to save
    /// - Throws: Database errors
    func save(_ memory: AgentMemory) throws {
        let dbQueue = try dbService.getQueue()

        try dbQueue.write { db in
            try memory.save(db)
        }

        print("💾 [AgentMemoryRepository] Saved memory '\(memory.id)' of kind '\(memory.kind.rawValue)'")
    }

    // MARK: - Read

    /// Find memories by tags (matches any of the provided tags)
    /// - Parameter tags: Tags to search for
    /// - Returns: Array of matching memories
    func findByTags(_ tags: [String]) throws -> [AgentMemory] {
        guard !tags.isEmpty else { return [] }

        let dbQueue = try dbService.getQueue()

        return try dbQueue.read { db in
            // Query all memories and filter by tags in Swift
            // (SQLite JSON querying is complex, so we filter in-memory)
            let allMemories = try AgentMemory.fetchAll(db)

            return allMemories.filter { memory in
                // Check if any of the memory's tags match any of the search tags
                !Set(memory.tags).intersection(tags).isEmpty
            }
        }
    }

    /// Find memories by kind
    /// - Parameter kind: The memory kind to filter by
    /// - Returns: Array of memories of the specified kind
    func findByKind(_ kind: AgentMemory.MemoryKind) throws -> [AgentMemory] {
        let dbQueue = try dbService.getQueue()

        return try dbQueue.read { db in
            try AgentMemory
                .filter(AgentMemory.Columns.kind == kind.rawValue)
                .order(AgentMemory.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Get the most recent memories
    /// - Parameter limit: Maximum number of memories to return
    /// - Returns: Array of recent memories
    func getRecent(limit: Int = 10) throws -> [AgentMemory] {
        let dbQueue = try dbService.getQueue()

        return try dbQueue.read { db in
            try AgentMemory
                .order(AgentMemory.Columns.createdAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Get all memories (sorted by creation date, newest first)
    /// - Returns: Array of all memories
    func getAll() throws -> [AgentMemory] {
        let dbQueue = try dbService.getQueue()

        return try dbQueue.read { db in
            try AgentMemory
                .order(AgentMemory.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Find memories within a date range
    /// - Parameters:
    ///   - from: Start date
    ///   - to: End date
    /// - Returns: Array of memories created within the date range
    func findByDateRange(from: Date, to: Date) throws -> [AgentMemory] {
        let dbQueue = try dbService.getQueue()

        return try dbQueue.read { db in
            try AgentMemory
                .filter(AgentMemory.Columns.createdAt >= from && AgentMemory.Columns.createdAt <= to)
                .order(AgentMemory.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Get a memory by ID
    /// - Parameter id: The memory ID
    /// - Returns: The memory if found, nil otherwise
    func findById(_ id: String) throws -> AgentMemory? {
        let dbQueue = try dbService.getQueue()

        return try dbQueue.read { db in
            try AgentMemory.fetchOne(db, key: id)
        }
    }

    // MARK: - Update

    /// Update the access time and increment access count for a memory
    /// - Parameter id: The memory ID
    /// - Throws: Database errors
    func updateAccessTime(_ id: String) throws {
        let dbQueue = try dbService.getQueue()

        try dbQueue.write { db in
            guard var memory = try AgentMemory.fetchOne(db, key: id) else {
                return
            }

            memory.lastAccessed = Date()
            memory.accessCount += 1

            try memory.update(db)
        }
    }

    // MARK: - Delete

    /// Delete a memory by ID
    /// - Parameter id: The memory ID
    /// - Returns: True if deleted, false if not found
    @discardableResult
    func delete(_ id: String) throws -> Bool {
        let dbQueue = try dbService.getQueue()

        return try dbQueue.write { db in
            try AgentMemory.deleteOne(db, key: id)
        }
    }

    /// Delete all memories
    func deleteAll() throws {
        let dbQueue = try dbService.getQueue()

        try dbQueue.write { db in
            try AgentMemory.deleteAll(db)
        }
    }

    // MARK: - Statistics

    /// Get count of memories by kind
    /// - Returns: Dictionary mapping kind to count
    func getCountsByKind() throws -> [AgentMemory.MemoryKind: Int] {
        let dbQueue = try dbService.getQueue()

        return try dbQueue.read { db in
            let allMemories = try AgentMemory.fetchAll(db)

            var counts: [AgentMemory.MemoryKind: Int] = [:]
            for memory in allMemories {
                counts[memory.kind, default: 0] += 1
            }

            return counts
        }
    }

    /// Get total count of memories
    /// - Returns: Total number of memories
    func getCount() throws -> Int {
        let dbQueue = try dbService.getQueue()

        return try dbQueue.read { db in
            try AgentMemory.fetchCount(db)
        }
    }
}
