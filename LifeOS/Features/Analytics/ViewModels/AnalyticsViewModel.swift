//
//  AnalyticsViewModel.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import Foundation
import SwiftUI

/// View model for analytics dashboard
@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var timeSeries: [TimeSeriesDataPoint] = []
    @Published var selectedDateRange: DateInterval = Calendar.current.dateInterval(of: .month, for: Date())!
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var hasData: Bool = false

    private let calculator: HappinessIndexCalculator
    private let analyticsRepository: EntryAnalyticsRepository

    init(calculator: HappinessIndexCalculator, analyticsRepository: EntryAnalyticsRepository) {
        self.calculator = calculator
        self.analyticsRepository = analyticsRepository
    }

    /// Load analytics data for the selected date range
    func loadAnalytics() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            timeSeries = try await calculator.computeTimeSeriesDataPoints(
                from: selectedDateRange.start,
                to: selectedDateRange.end,
                repository: analyticsRepository
            )
            hasData = !timeSeries.isEmpty
        } catch {
            self.error = error
            hasData = false
        }
    }

    /// Refresh analytics data
    func refreshAnalytics() async {
        await loadAnalytics()
    }

    /// Update date range and reload data
    func updateDateRange(_ range: DateInterval) {
        selectedDateRange = range
        Task {
            await loadAnalytics()
        }
    }

    /// Set date range to last N days
    func setDateRange(days: Int) {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        selectedDateRange = DateInterval(start: start, end: end)
        Task {
            await loadAnalytics()
        }
    }
}
