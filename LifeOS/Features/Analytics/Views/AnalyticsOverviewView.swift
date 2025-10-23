//
//  AnalyticsOverviewView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI
import Charts

/// Overview tab showing key metrics and recent highlights
struct AnalyticsOverviewView: View {
    @ObservedObject var viewModel: AnalyticsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                metricsSection

                if !viewModel.timeSeries.isEmpty {
                    miniChartSection
                }

                highlightsSection
            }
            .padding()
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)

            HStack(spacing: 16) {
                MetricCardView(
                    title: "Current",
                    value: currentHappiness,
                    trend: nil,
                    icon: "heart.fill"
                )

                MetricCardView(
                    title: "Average",
                    value: averageHappiness,
                    trend: nil,
                    icon: "chart.line.uptrend.xyaxis"
                )

                MetricCardView(
                    title: "Entries",
                    value: "\(viewModel.timeSeries.count)",
                    trend: nil,
                    icon: "doc.text.fill"
                )
            }
        }
    }

    private var miniChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Happiness Trend")
                .font(.headline)

            Chart {
                ForEach(viewModel.timeSeries.prefix(90)) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Happiness", point.value)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 150)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Highlights")
                .font(.headline)

            Text("Event highlights will appear here once summaries are generated")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
        }
    }

    private var currentHappiness: String {
        guard let latest = viewModel.timeSeries.last else { return "--" }
        return String(Int(latest.value))
    }

    private var averageHappiness: String {
        guard !viewModel.timeSeries.isEmpty else { return "--" }
        let avg = viewModel.timeSeries.map { $0.value }.reduce(0, +) / Double(viewModel.timeSeries.count)
        return String(Int(avg))
    }
}

#Preview {
    Text("AnalyticsOverviewView requires ViewModel")
}
