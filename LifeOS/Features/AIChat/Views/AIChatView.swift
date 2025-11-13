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
    @Environment(SidebarHoverManager.self) private var hoverManager
    @StateObject private var viewModel: AIChatViewModel
    @State private var messageText: String = ""

    init(agentKernel: AgentKernel) {
        _viewModel = StateObject(wrappedValue: AIChatViewModel(agentKernel: agentKernel))
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                theme.surfaceColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Messages container
                    ChatMessagesContainerView(
                        messages: viewModel.currentMessages,
                        isLoading: viewModel.isLoading
                    )

                    // Error banner
                    if let error = viewModel.error {
                        errorBanner(error)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
            .overlay(
                EdgeHintView(
                    isLeftEdge: true,
                    isVisible: !hoverManager.isLeftSidebarOpen
                        && !hoverManager.isLeftSidebarPinned
                )
            )
            .overlay(
                EdgeHintView(
                    isLeftEdge: false,
                    isVisible: !hoverManager.isRightSidebarOpen(for: .aiChat)
                        && !hoverManager.isRightSidebarPinned(for: .aiChat)
                )
            )

            if hoverManager.isRightSidebarOpen(for: .aiChat) {
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
                    onCopyConversation: { conversationId in
                        copyConversationToClipboard(conversationId: conversationId)
                    },
                    onNewConversation: {
                        viewModel.createNewConversation()
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hoverManager.isRightSidebarOpen(for: .aiChat))
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

    private func copyConversationToClipboard(conversationId: UUID) {
        guard let conversation = viewModel.conversations.first(where: { $0.id == conversationId }) else { return }
        let messages = conversation.messages
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
