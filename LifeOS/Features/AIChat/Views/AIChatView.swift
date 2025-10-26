//
//  AIChatView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI
import AppKit

/// Full-screen AI chat interface with conversation history
struct AIChatView: View {
    @Environment(\.theme) private var theme
    @StateObject private var viewModel: AIChatViewModel
    @State private var messageText: String = ""
    @State private var isHoveringHistoryButton = false
    @State private var isHoveringClipboardButton = false
    @State private var scrollToMessageId: UUID?

    init(agentKernel: AgentKernel) {
        _viewModel = StateObject(wrappedValue: AIChatViewModel(agentKernel: agentKernel))
    }

    private func groupMessagesByDate() -> [(date: Date, messages: [ChatMessage])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.currentMessages) { message in
            calendar.startOfDay(for: message.timestamp)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, messages: $0.value.sorted { $0.timestamp < $1.timestamp }) }
    }

    private func formatDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let messageDate = calendar.startOfDay(for: date)

        if messageDate == today {
            return "Today"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), messageDate == yesterday {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Messages
                messagesView

                // Error banner
                if let error = viewModel.error {
                    errorBanner(error)
                }

                // Input
                ChatInputView(
                    messageText: $messageText,
                    onSend: { text in
                        Task {
                            await viewModel.sendMessage(text)
                        }
                    },
                    isLoading: viewModel.isLoading
                )

                // Bottom row with buttons
                HStack {
                    Spacer()
                    bottomRightButtons
                }
                .padding()
                .frame(height: 60)
            }
            .background(theme.surfaceColor)

            if viewModel.showingHistory {
                Divider()

                ChatHistoryView(
                    conversations: viewModel.conversations,
                    currentConversationId: viewModel.currentConversationId,
                    onConversationTap: { conversationId in
                        viewModel.switchConversation(id: conversationId)
                    },
                    onDeleteConversation: { conversationId in
                        viewModel.deleteConversation(id: conversationId)
                    },
                    onNewConversation: {
                        viewModel.createNewConversation()
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showingHistory)
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.currentMessages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(groupMessagesByDate(), id: \.date) { group in
                            // Date separator
                            Text(formatDateLabel(group.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)

                            // Messages for this date
                            ForEach(group.messages) { message in
                                MessageBubbleView(message: message)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    if viewModel.isLoading {
                        TypingIndicatorView()
                            .padding(.horizontal)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottomMarker")
                }
                .frame(maxWidth: 700)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.never)
            .background(theme.surfaceColor)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo("bottomMarker", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.currentMessages.count) { oldCount, newCount in
                // Only auto-scroll if we're adding messages (not removing)
                if newCount > oldCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation {
                            proxy.scrollTo("bottomMarker", anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: viewModel.currentConversationId) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation {
                        proxy.scrollTo("bottomMarker", anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    // Scroll to bottom when loading starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("bottomMarker", anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: scrollToMessageId) { _, messageId in
                if let messageId = messageId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation {
                            proxy.scrollTo(messageId, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("Ask me anything")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("I can help you understand patterns in your journal, reflect on experiences, and gain insights about your life.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Try asking:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach([
                    "How have I been feeling this month?",
                    "What made me happy last week?",
                    "What are my main stressors?",
                    "Show me my happiness trends"
                ], id: \.self) { suggestion in
                    Button(action: {
                        messageText = suggestion
                    }) {
                        Text(suggestion)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.hoveredBackground)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.top)
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
            Button("Dismiss") {
                viewModel.error = nil
            }
            .font(.caption)
        }
        .padding()
        .background(Color.red.opacity(0.1))
    }

    private func copyConversationToClipboard() {
        let messages = viewModel.currentMessages
        guard !messages.isEmpty else { return }

        let conversationText: String = messages.map { message in
            let role = message.role == .user ? "User" : "Assistant"
            var text = "\(role): \(message.content)"

            if !message.toolsUsed.isEmpty {
                text += "\n[Tools used: \(message.toolsUsed.joined(separator: ", "))]"
            }

            return text
        }.joined(separator: "\n\n")

        let pasteboard = AppKit.NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(conversationText, forType: AppKit.NSPasteboard.PasteboardType.string)
    }

    private var bottomRightButtons: some View {
        HStack(spacing: 12) {
            // Clipboard button
            Button(action: copyConversationToClipboard) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14))
                    .foregroundColor(isHoveringClipboardButton ? theme.buttonTextHover : theme.buttonText)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringClipboardButton = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            // History button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showingHistory.toggle()
                }
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14))
                    .foregroundColor(isHoveringHistoryButton ? theme.buttonTextHover : theme.buttonText)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringHistoryButton = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}

#Preview {
    // Mock preview - would need actual agent kernel in real app
    struct PreviewWrapper: View {
        var body: some View {
            Text("AIChatView requires AgentKernel initialization")
        }
    }
    return PreviewWrapper()
}
