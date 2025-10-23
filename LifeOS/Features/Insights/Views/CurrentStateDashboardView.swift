//
//  CurrentStateDashboardView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Main dashboard showing current life state analysis
struct CurrentStateDashboardView: View {
    @StateObject private var viewModel: CurrentStateDashboardViewModel

    init(analyzer: CurrentStateAnalyzer, fileManager: FileManagerService) {
        _viewModel = StateObject(wrappedValue: CurrentStateDashboardViewModel(
            analyzer: analyzer,
            fileManager: fileManager
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.currentState == nil {
                loadingView
            } else if let state = viewModel.currentState {
                contentView(state: state)
            } else {
                emptyStateView
            }
        }
        .task {
            await viewModel.loadCurrentState()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing your recent entries...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Data Available")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Process your journal entries to see insights about your current state.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let error = viewModel.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }

            Button("Retry") {
                Task {
                    await viewModel.refreshState()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func contentView(state: CurrentState) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Mood Gauges
                moodGaugesSection(state: state)

                // Themes
                themesSection(state: state)

                // Stressors & Protective Factors
                stressorsProtectiveSection(state: state)

                // AI Suggestions
                suggestionsSection(state: state)
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshState()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("How You're Doing")
                    .font(.title)
                    .fontWeight(.bold)

                if let lastUpdated = viewModel.lastUpdated {
                    Text("Based on last 30 days • Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Based on last 30 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                Task {
                    await viewModel.refreshState()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
            }
            .disabled(viewModel.isLoading)
        }
    }

    private func moodGaugesSection(state: CurrentState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mood Metrics")
                .font(.headline)

            HStack(spacing: 20) {
                MoodGaugeView(
                    metric: "Happiness",
                    value: state.mood.happiness,
                    trend: state.mood.happinessTrend,
                    icon: "heart.fill"
                )

                MoodGaugeView(
                    metric: "Stress",
                    value: state.mood.stress,
                    trend: state.mood.stressTrend,
                    icon: "bolt.fill"
                )

                MoodGaugeView(
                    metric: "Energy",
                    value: state.mood.energy,
                    trend: state.mood.energyTrend,
                    icon: "battery.100"
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func themesSection(state: CurrentState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Themes")
                .font(.headline)

            ThemeChipsView(themes: state.themes)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func stressorsProtectiveSection(state: CurrentState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            StressorsProtectiveView(
                stressors: state.stressors,
                protectiveFactors: state.protectiveFactors
            )
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func suggestionsSection(state: CurrentState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            AISuggestedTodosView(
                todos: state.suggestedTodos,
                onAdd: { todo in
                    viewModel.addTodoToJournal(todo)
                }
            )
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    Text("CurrentStateDashboardView requires full initialization")
}
