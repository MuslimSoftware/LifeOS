//
//  HappinessChartView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI
import Charts

/// Full-screen interactive happiness chart with zoom controls
struct HappinessChartView: View {
    @ObservedObject var viewModel: AnalyticsViewModel

    enum ZoomLevel: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "ALL"

        var days: Int? {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            case .all: return nil
            }
        }
    }

    @State private var selectedZoom: ZoomLevel = .threeMonths

    var body: some View {
        VStack(spacing: 16) {
            // Zoom controls
            zoomControls

            // Chart
            if viewModel.timeSeries.isEmpty {
                emptyChart
            } else {
                happinessChart
            }
        }
        .padding()
    }

    private var zoomControls: some View {
        HStack {
            Text("Happiness Chart")
                .font(.headline)

            Spacer()

            Picker("Zoom", selection: $selectedZoom) {
                ForEach(ZoomLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            .onChange(of: selectedZoom) { _, newValue in
                if let days = newValue.days {
                    viewModel.setDateRange(days: days)
                } else {
                    // Show all data
                    viewModel.setDateRange(days: 365 * 10) // 10 years
                }
            }
        }
    }

    private var happinessChart: some View {
        Chart {
            ForEach(filteredData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Happiness", point.value)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100])
        }
        .frame(maxHeight: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var emptyChart: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No data available for selected period")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private var filteredData: [TimeSeriesDataPoint] {
        guard let days = selectedZoom.days else {
            return viewModel.timeSeries
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return viewModel.timeSeries.filter { $0.date >= cutoffDate }
    }
}

#Preview {
    Text("HappinessChartView requires ViewModel")
}
