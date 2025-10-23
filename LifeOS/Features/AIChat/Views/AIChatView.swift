//
//  AIChatView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Full-screen AI chat interface with conversation history
struct AIChatView: View {
    @StateObject private var viewModel: AIChatViewModel
    @State private var messageText: String = ""
    @State private var showClearConfirmation = false

    init(agentKernel: AgentKernel) {
        _viewModel = StateObject(wrappedValue: AIChatViewModel(agentKernel: agentKernel))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

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
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Assistant")
                    .font(.headline)
                if !viewModel.messages.isEmpty {
                    Text("\(viewModel.messages.count) messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { showClearConfirmation = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .disabled(viewModel.messages.isEmpty)
            .confirmationDialog("Clear Conversation", isPresented: $showClearConfirmation) {
                Button("Clear All Messages", role: .destructive) {
                    viewModel.clearConversation()
                }
            } message: {
                Text("This will delete all conversation history. This action cannot be undone.")
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .padding(.horizontal)
                        }
                    }

                    if viewModel.isLoading {
                        TypingIndicatorView()
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    // Scroll to bottom when loading starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            if let lastMessage = viewModel.messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
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
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.top)
        }
        .padding()
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
