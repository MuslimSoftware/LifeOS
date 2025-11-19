//
//  ChatMessagesContainerView.swift
//  LifeOS
//
//  Created by Claude on 11/12/25.
//

import SwiftUI

struct ChatMessagesContainerView: View {
    @Environment(\.theme) private var theme
    let messages: [ChatMessage]
    let isLoading: Bool
    let onScrollToBottom: (() -> Void)?

    init(
        messages: [ChatMessage],
        isLoading: Bool = false,
        onScrollToBottom: (() -> Void)? = nil
    ) {
        self.messages = messages
        self.isLoading = isLoading
        self.onScrollToBottom = onScrollToBottom
    }

    private func groupMessagesByDate() -> [(date: Date, messages: [ChatMessage])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messages) { message in
            calendar.startOfDay(for: message.timestamp)
        }
        return grouped.sorted { $0.key < $1.key }.map {
            (date: $0.key, messages: $0.value.sorted { $0.timestamp < $1.timestamp })
        }
    }

    private func formatDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let messageDate = calendar.startOfDay(for: date)

        if messageDate == today {
            return "Today"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  messageDate == yesterday {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 32)

                    if messages.isEmpty {
                        emptyStateView
                    } else {
                        messagesListView
                    }

                    if isLoading {
                        VStack {
                            TypingIndicatorView()
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                        }
                        .frame(maxWidth: 800)
                        .frame(maxWidth: .infinity)
                    }

                    Color.clear.frame(height: 32)
                        .id("bottomMarker")
                }
            }
            .scrollIndicators(.hidden)
            .background(theme.surfaceColor)
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.count) { oldCount, newCount in
                if newCount > oldCount {
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
            .onChange(of: isLoading) { _, loading in
                if loading {
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
        }
    }

    private var messagesListView: some View {
        LazyVStack(spacing: 24) {
            ForEach(groupMessagesByDate(), id: \.date) { group in
                VStack(spacing: 16) {
                    Text(formatDateLabel(group.date))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.hoveredBackground)
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)

                    ForEach(group.messages) { message in
                        MessageBubbleView(message: message)
                            .padding(.horizontal, 20)
                            .id(message.id)
                    }
                }
            }
        }
        .frame(maxWidth: 800)
        .frame(maxWidth: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("Ask me anything")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("I can help you understand patterns in your journal, reflect on experiences, and gain insights about your life.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = false) {
        let delay: TimeInterval = animated ? 0.05 : 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if animated {
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottomMarker", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("bottomMarker", anchor: .bottom)
            }
        }
    }
}

#Preview {
    ChatMessagesContainerView(
        messages: [
            ChatMessage(role: .user, content: "Hello!"),
            ChatMessage(role: .assistant, content: "Hi there! How can I help?")
        ],
        isLoading: false
    )
}
