//
//  MetricCardView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Reusable card for displaying a single metric
struct MetricCardView: View {
    let title: String
    let value: String
    let trend: Trend?
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)

            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let trend = trend {
                    Image(systemName: trendIcon(trend))
                        .font(.caption)
                        .foregroundColor(trendColor(trend))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func trendIcon(_ trend: Trend) -> String {
        switch trend {
        case .up:
            return "arrow.up.right"
        case .down:
            return "arrow.down.right"
        case .stable:
            return "arrow.right"
        }
    }

    private func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .up:
            return .green
        case .down:
            return .red
        case .stable:
            return .gray
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        MetricCardView(title: "Current Happiness", value: "72", trend: .up, icon: "heart.fill")
        MetricCardView(title: "30-Day Average", value: "68", trend: .stable, icon: "chart.line.uptrend.xyaxis")
        MetricCardView(title: "Entries", value: "145", trend: nil, icon: "doc.text.fill")
    }
    .padding()
}
