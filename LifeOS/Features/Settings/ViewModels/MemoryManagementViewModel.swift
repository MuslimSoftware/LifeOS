import Foundation
import SwiftUI

@MainActor
class MemoryManagementViewModel: ObservableObject {
    @Published var memories: [AgentMemory] = []
    @Published var filteredMemories: [AgentMemory] = []
    @Published var searchText: String = "" {
        didSet { applyFilters() }
    }
    @Published var selectedKindFilter: AgentMemory.MemoryKind? {
        didSet { applyFilters() }
    }
    @Published var selectedTagFilter: String? {
        didSet { applyFilters() }
    }
    @Published var sortOrder: SortOrder = .newestFirst {
        didSet { applyFilters() }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repository: AgentMemoryRepository

    enum SortOrder: String, CaseIterable {
        case newestFirst = "Newest First"
        case oldestFirst = "Oldest First"
        case mostUsed = "Most Used"
        case leastUsed = "Least Used"
    }

    init(repository: AgentMemoryRepository) {
        self.repository = repository
    }

    // MARK: - Data Loading

    func loadMemories() async {
        isLoading = true
        errorMessage = nil

        do {
            memories = try repository.getAll()
            applyFilters()
        } catch {
            errorMessage = "Failed to load memories: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Filtering & Sorting

    func applyFilters() {
        var result = memories

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { memory in
                memory.content.localizedCaseInsensitiveContains(searchText) ||
                memory.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }

        // Apply kind filter
        if let kindFilter = selectedKindFilter {
            result = result.filter { $0.kind == kindFilter }
        }

        // Apply tag filter
        if let tagFilter = selectedTagFilter {
            result = result.filter { $0.tags.contains(tagFilter) }
        }

        // Apply sorting
        switch sortOrder {
        case .newestFirst:
            result.sort { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            result.sort { $0.createdAt < $1.createdAt }
        case .mostUsed:
            result.sort { $0.accessCount > $1.accessCount }
        case .leastUsed:
            result.sort { $0.accessCount < $1.accessCount }
        }

        filteredMemories = result
    }

    // MARK: - Memory Management

    func deleteMemory(id: String) async {
        do {
            try repository.delete(id)
            memories.removeAll { $0.id == id }
            applyFilters()
        } catch {
            errorMessage = "Failed to delete memory: \(error.localizedDescription)"
        }
    }

    func deleteAllMemories() async {
        do {
            try repository.deleteAll()
            memories.removeAll()
            filteredMemories.removeAll()
        } catch {
            errorMessage = "Failed to delete all memories: \(error.localizedDescription)"
        }
    }

    // MARK: - Statistics

    var totalCount: Int {
        memories.count
    }

    var filteredCount: Int {
        filteredMemories.count
    }

    var countsByKind: [AgentMemory.MemoryKind: Int] {
        var counts: [AgentMemory.MemoryKind: Int] = [:]
        for memory in memories {
            counts[memory.kind, default: 0] += 1
        }
        return counts
    }

    var allTags: [String] {
        let tagSet = Set(memories.flatMap { $0.tags })
        return Array(tagSet).sorted()
    }

    var totalAccessCount: Int {
        memories.reduce(0) { $0 + $1.accessCount }
    }

    // MARK: - Helper Functions

    func kindDisplayName(_ kind: AgentMemory.MemoryKind) -> String {
        switch kind {
        case .insight: return "Insight"
        case .decision: return "Decision"
        case .todo: return "Todo"
        case .rule: return "Rule"
        case .value: return "Value"
        case .commitment: return "Commitment"
        }
    }

    func kindIcon(_ kind: AgentMemory.MemoryKind) -> String {
        switch kind {
        case .insight: return "lightbulb.fill"
        case .decision: return "checkmark.circle.fill"
        case .todo: return "list.bullet.circle.fill"
        case .rule: return "book.fill"
        case .value: return "heart.fill"
        case .commitment: return "hand.raised.fill"
        }
    }

    func confidenceColor(_ confidence: AgentMemory.Confidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}
