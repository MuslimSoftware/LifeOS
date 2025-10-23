//
//  MonthDetailView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Sheet presentation showing detailed monthly summary
struct MonthDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let month: MonthSummary

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with happiness score
                    headerSection

                    // AI-generated summary
                    summarySection

                    // Statistics
                    statisticsSection

                    // What went well / challenges
                    driversSection

                    // Top events
                    eventsSection
                }
                .padding()
            }
            .navigationTitle(monthTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var monthTitle: String {
        let monthName = Calendar.current.monthSymbols[month.month - 1]
        return "\(monthName) \(month.year)"
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Happiness Score")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f", month.happinessAvg))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(happinessColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Range")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f - %.0f", month.happinessConfidenceInterval.lower, month.happinessConfidenceInterval.upper))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)

            Text(month.summaryText)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Text("Average Happiness:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", month.happinessAvg))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Confidence Interval:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f - %.1f", month.happinessConfidenceInterval.lower, month.happinessConfidenceInterval.upper))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var driversSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Positive drivers
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("What Went Well")
                        .font(.headline)
                        .foregroundColor(.green)
                }

                ForEach(month.driversPositive, id: \.self) { driver in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.green)
                        Text(driver)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )

            // Negative drivers
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Challenges")
                        .font(.headline)
                        .foregroundColor(.red)
                }

                ForEach(month.driversNegative, id: \.self) { driver in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.red)
                        Text(driver)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color.red.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Events")
                .font(.headline)

            if month.topEvents.isEmpty {
                Text("No events detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(month.topEvents) { event in
                    EventChipView(event: event)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var happinessColor: Color {
        let value = month.happinessAvg
        if value >= 70 {
            return .green
        } else if value >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    Text("MonthDetailView requires MonthSummary")
}
