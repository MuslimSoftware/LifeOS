//
//  ThemeChipsView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Horizontal scrolling chips for displaying life themes
struct ThemeChipsView: View {
    let themes: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(themes, id: \.self) { theme in
                    themeChip(theme)
                }
            }
        }
    }

    private func themeChip(_ theme: String) -> some View {
        HStack(spacing: 6) {
            Text(themeIcon(theme))
                .font(.body)
            Text(theme)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeColor(theme).opacity(0.2))
        .foregroundColor(themeColor(theme))
        .cornerRadius(16)
    }

    private func themeIcon(_ theme: String) -> String {
        let lowercased = theme.lowercased()
        if lowercased.contains("work") || lowercased.contains("career") {
            return "💼"
        } else if lowercased.contains("health") || lowercased.contains("fitness") {
            return "❤️"
        } else if lowercased.contains("relationship") || lowercased.contains("social") || lowercased.contains("friend") {
            return "👥"
        } else if lowercased.contains("family") {
            return "👨‍👩‍👧‍👦"
        } else if lowercased.contains("financial") || lowercased.contains("money") {
            return "💰"
        } else if lowercased.contains("personal") || lowercased.contains("growth") {
            return "🌱"
        } else if lowercased.contains("hobby") || lowercased.contains("creative") {
            return "🎨"
        } else {
            return "✨"
        }
    }

    private func themeColor(_ theme: String) -> Color {
        let lowercased = theme.lowercased()
        if lowercased.contains("work") || lowercased.contains("career") {
            return .blue
        } else if lowercased.contains("health") || lowercased.contains("fitness") {
            return .red
        } else if lowercased.contains("relationship") || lowercased.contains("social") || lowercased.contains("friend") {
            return .purple
        } else if lowercased.contains("family") {
            return .orange
        } else if lowercased.contains("financial") || lowercased.contains("money") {
            return .green
        } else {
            return .accentColor
        }
    }
}

#Preview {
    ThemeChipsView(themes: [
        "Career growth",
        "Health & fitness",
        "Social connections",
        "Financial planning",
        "Personal development"
    ])
    .padding()
}
