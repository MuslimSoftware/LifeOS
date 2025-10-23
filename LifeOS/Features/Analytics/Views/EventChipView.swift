//
//  EventChipView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Chip-style view for displaying detected events
struct EventChipView: View {
    let event: DetectedEvent

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(sentimentColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let date = event.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var sentimentColor: Color {
        if event.sentiment > 0.3 {
            return .green
        } else if event.sentiment < -0.3 {
            return .red
        } else {
            return .gray
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        EventChipView(event: DetectedEvent(
            id: UUID(),
            title: "Coffee with Sarah",
            date: Date(),
            description: "Great catch-up",
            sentiment: 0.8
        ))
        EventChipView(event: DetectedEvent(
            id: UUID(),
            title: "Project deadline stress",
            date: Date(),
            description: "Feeling overwhelmed",
            sentiment: -0.6
        ))
        EventChipView(event: DetectedEvent(
            id: UUID(),
            title: "Regular day",
            date: Date(),
            description: "Nothing special",
            sentiment: 0.0
        ))
    }
    .padding()
}
