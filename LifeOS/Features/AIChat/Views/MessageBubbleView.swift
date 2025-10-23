//
//  MessageBubbleView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Message bubble with rich formatting and tool badges
struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Message content
                Text(markdownAttributedString)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)

                // Tool badges (AI only)
                if message.role == .assistant && !message.toolsUsed.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(message.toolsUsed, id: \.self) { tool in
                            ToolBadgeView(toolName: tool)
                        }
                    }
                }

                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
        .id(message.id)
    }

    private var bubbleColor: Color {
        message.role == .user ? Color.accentColor : Color(nsColor: .controlBackgroundColor)
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }

    private var markdownAttributedString: AttributedString {
        do {
            var attributedString = try AttributedString(markdown: message.content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))

            // Apply text color to all text
            attributedString.foregroundColor = textColor

            return attributedString
        } catch {
            // Fallback to plain text if markdown parsing fails
            return AttributedString(message.content)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(message: ChatMessage(
            role: .user,
            content: "How have I been feeling this month?"
        ))

        MessageBubbleView(message: ChatMessage(
            role: .assistant,
            content: """
            Based on your October journal entries, your happiness has been trending upward with an average of **72/100**.

            Key highlights:
            - **Hiking trips** on Oct 12th and 19th energized you
            - **Social connections** brought joy (coffee with Sarah on Oct 8th)
            - **Work wins** with the new feature launch (Oct 15th)

            Your mood peaked around Oct 19-23, averaging 78/100 during that week.
            """,
            toolsUsed: ["search_semantic", "get_month_summary"]
        ))
    }
    .padding()
}
