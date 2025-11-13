//
//  MessageBubbleView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Message bubble with rich formatting and tool badges
struct MessageBubbleView: View {
    @Environment(\.theme) private var theme
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 0)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Message content
                Text(markdownAttributedString)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
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
            .frame(maxWidth: 600, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer(minLength: 0)
            }
        }
        .id(message.id)
    }

    private var bubbleColor: Color {
        message.role == .user ? Color.accentColor : theme.hoveredBackground
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }

    private var markdownAttributedString: AttributedString {
        // Pre-process content to style headers while preserving line breaks
        let processedContent = message.content
        var attributedString = AttributedString()

        // Split by lines to process headers
        let lines = processedContent.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            var lineAttr: AttributedString

            // Check if line is a header
            if line.hasPrefix("### ") {
                let headerText = line.replacingOccurrences(of: "### ", with: "")
                lineAttr = AttributedString(headerText)
                lineAttr.font = .system(size: 17, weight: .semibold)
            } else if line.hasPrefix("## ") {
                let headerText = line.replacingOccurrences(of: "## ", with: "")
                lineAttr = AttributedString(headerText)
                lineAttr.font = .system(size: 20, weight: .bold)
            } else if line.hasPrefix("# ") {
                let headerText = line.replacingOccurrences(of: "# ", with: "")
                lineAttr = AttributedString(headerText)
                lineAttr.font = .system(size: 24, weight: .bold)
            } else {
                // Parse line with inline markdown (bold, italic, etc.) while preserving whitespace
                let options = AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
                lineAttr = (try? AttributedString(markdown: line, options: options)) ?? AttributedString(line)
            }

            attributedString.append(lineAttr)

            // Add newline between lines (except after last line)
            if index < lines.count - 1 {
                attributedString.append(AttributedString("\n"))
            }
        }

        // Apply text color to all text
        attributedString.foregroundColor = textColor

        return attributedString
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
