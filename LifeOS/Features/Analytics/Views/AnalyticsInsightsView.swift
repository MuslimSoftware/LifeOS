//
//  AnalyticsInsightsView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Insights tab showing patterns and recommendations
struct AnalyticsInsightsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Insights")
                    .font(.headline)

                Text("AI-powered insights and pattern detection will appear here once enough data is processed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Coming Soon:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    insightPlaceholder(
                        icon: "chart.bar.xaxis",
                        title: "Correlations",
                        description: "Discover patterns like 'Your happiness is 15% higher on weekends'"
                    )

                    insightPlaceholder(
                        icon: "calendar.badge.clock",
                        title: "Patterns",
                        description: "Find when you're most productive or reflective"
                    )

                    insightPlaceholder(
                        icon: "arrow.up.right",
                        title: "Growth",
                        description: "Track your emotional growth over time"
                    )

                    insightPlaceholder(
                        icon: "lightbulb",
                        title: "Recommendations",
                        description: "Get personalized suggestions based on your patterns"
                    )
                }
            }
            .padding()
        }
    }

    private func insightPlaceholder(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

#Preview {
    AnalyticsInsightsView()
}
