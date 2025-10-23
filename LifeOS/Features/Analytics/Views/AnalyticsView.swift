//
//  AnalyticsView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Main analytics dashboard container with tab navigation
struct AnalyticsView: View {
    @StateObject private var viewModel: AnalyticsViewModel
    let onNavigateToSettings: () -> Void

    init(calculator: HappinessIndexCalculator, analyticsRepository: EntryAnalyticsRepository, onNavigateToSettings: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AnalyticsViewModel(
            calculator: calculator,
            analyticsRepository: analyticsRepository
        ))
        self.onNavigateToSettings = onNavigateToSettings
    }

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.hasData {
                loadingView
            } else if !viewModel.hasData {
                EmptyAnalyticsView(onNavigateToSettings: onNavigateToSettings)
            } else {
                tabContent
            }
        }
        .task {
            await viewModel.loadAnalytics()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading analytics...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    private var tabContent: some View {
        TabView {
            AnalyticsOverviewView(viewModel: viewModel)
                .tabItem {
                    Label("Overview", systemImage: "chart.bar")
                }

            HappinessChartView(viewModel: viewModel)
                .tabItem {
                    Label("Happiness", systemImage: "heart")
                }

            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }

            AnalyticsInsightsView()
                .tabItem {
                    Label("Insights", systemImage: "lightbulb")
                }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task {
                        await viewModel.refreshAnalytics()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
}

#Preview {
    Text("AnalyticsView requires full initialization")
}
