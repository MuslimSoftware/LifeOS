//
//  MoodGaugeView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Circular gauge for displaying mood metrics (happiness, stress, energy)
struct MoodGaugeView: View {
    let metric: String
    let value: Double
    let trend: Trend?
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 100, height: 100)

                // Progress circle
                Circle()
                    .trim(from: 0, to: value / 100)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: value)

                // Center content
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(gaugeColor)
                    Text("\(Int(value))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(gaugeColor)
                }

                // Trend badge
                if let trend = trend {
                    Image(systemName: trendIcon(trend))
                        .font(.caption)
                        .foregroundColor(trendColor(trend))
                        .padding(4)
                        .background(Circle().fill(trendColor(trend).opacity(0.2)))
                        .offset(x: 45, y: -45)
                }
            }

            Text(metric)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var gaugeColor: Color {
        if value >= 70 {
            return .green
        } else if value >= 40 {
            return .orange
        } else {
            return .red
        }
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
    HStack(spacing: 30) {
        MoodGaugeView(metric: "Happiness", value: 72, trend: .up, icon: "heart.fill")
        MoodGaugeView(metric: "Stress", value: 45, trend: .stable, icon: "bolt.fill")
        MoodGaugeView(metric: "Energy", value: 68, trend: .down, icon: "battery.100")
    }
    .padding()
}
