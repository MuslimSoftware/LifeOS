//
//  CurrentStateDashboardViewModel.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import Foundation
import SwiftUI

/// View model managing current state dashboard data
@MainActor
class CurrentStateDashboardViewModel: ObservableObject {
    @Published var currentState: CurrentState?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var lastUpdated: Date?
    @Published var cacheValid: Bool = false

    private let analyzer: CurrentStateAnalyzer
    private let fileManager: FileManagerService
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour

    init(analyzer: CurrentStateAnalyzer, fileManager: FileManagerService) {
        self.analyzer = analyzer
        self.fileManager = fileManager
    }

    /// Load current state, using cache if valid
    func loadCurrentState(days: Int = 30) async {
        // Check cache validity
        if let lastUpdated = lastUpdated,
           Date().timeIntervalSince(lastUpdated) < cacheExpirationInterval,
           currentState != nil {
            cacheValid = true
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            currentState = try await analyzer.analyze(days: days)
            lastUpdated = Date()
            cacheValid = true
        } catch {
            self.error = error.localizedDescription
            cacheValid = false
        }
    }

    /// Force refresh current state
    func refreshState(days: Int = 30) async {
        lastUpdated = nil
        cacheValid = false
        await loadCurrentState(days: days)
    }

    /// Add AI-suggested todo to today's entry
    func addTodoToJournal(_ todo: AISuggestedTodo) {
        // Convert AISuggestedTodo to TODOItem
        let todoItem = TODOItem(
            text: todo.title,
            completed: false
        )

        // Get today's entry or create a new one
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        let entries = fileManager.loadExistingEntries()

        if let todayEntry = entries.first(where: {
            let entryDate = dateFormatter.date(from: $0.date)
            return entryDate != nil && Calendar.current.isDateInToday(entryDate!)
        }) {
            // Load, update and save existing entry
            if var content = fileManager.loadEntry(todayEntry) {
                content += "\n- [ ] \(todoItem.text)"
                fileManager.saveEntry(todayEntry, content: content)
            }
        } else {
            // Create new entry with todo
            let newEntry = HumanEntry.createNew()
            let content = "- [ ] \(todoItem.text)"
            fileManager.saveEntry(newEntry, content: content)
        }
    }

    /// Check if cache is still valid
    func checkCache() {
        if let lastUpdated = lastUpdated {
            cacheValid = Date().timeIntervalSince(lastUpdated) < cacheExpirationInterval
        } else {
            cacheValid = false
        }
    }
}
