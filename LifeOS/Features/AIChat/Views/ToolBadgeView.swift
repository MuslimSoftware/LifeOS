//
//  ToolBadgeView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Small badge showing which tool was used by the AI agent
struct ToolBadgeView: View {
    let toolName: String

    private var icon: String {
        switch toolName {
        case "search_semantic":
            return "magnifyingglass"
        case "get_month_summary":
            return "calendar"
        case "get_year_summary":
            return "calendar.badge.clock"
        case "get_time_series":
            return "chart.line.uptrend.xyaxis"
        case "get_current_state":
            return "person.crop.circle"
        default:
            return "wrench.and.screwdriver"
        }
    }

    private var displayName: String {
        toolName.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(displayName)
                .font(.system(size: 10))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.2))
        .foregroundColor(.secondary)
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 10) {
        ToolBadgeView(toolName: "search_semantic")
        ToolBadgeView(toolName: "get_month_summary")
        ToolBadgeView(toolName: "get_time_series")
    }
    .padding()
}
