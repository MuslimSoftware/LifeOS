//
//  AIChatViewModel.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import Foundation
import SwiftUI

/// View model managing AI chat interaction and conversation state
@MainActor
class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var toolsUsed: [String] = []

    private let agentKernel: AgentKernel
    private let persistenceService: ConversationPersistenceService

    init(agentKernel: AgentKernel, persistenceService: ConversationPersistenceService = ConversationPersistenceService()) {
        self.agentKernel = agentKernel
        self.persistenceService = persistenceService
        loadConversation()
    }

    /// Send a message to the AI agent
    func sendMessage(_ text: String) async {
        guard !text.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Convert to AgentMessage format (exclude tool-related messages)
            let history = messages.compactMap { $0.toAgentMessage() }

            // Call agent
            let response = try await agentKernel.runAgent(
                userMessage: text,
                conversationHistory: Array(history.dropLast()) // Exclude the message we just added
            )

            // Add AI response
            let aiMessage = ChatMessage(
                role: .assistant,
                content: response.text,
                toolsUsed: response.toolsUsed
            )
            messages.append(aiMessage)
            toolsUsed = response.toolsUsed

            // Persist conversation
            saveConversation()

        } catch {
            self.error = error.localizedDescription
            // Remove the user message if we failed to get a response
            if messages.last?.id == userMessage.id {
                messages.removeLast()
            }
        }
    }

    /// Clear all conversation history
    func clearConversation() {
        messages.removeAll()
        toolsUsed.removeAll()
        error = nil
        persistenceService.clearConversation()
    }

    /// Load conversation from persistent storage
    func loadConversation() {
        messages = persistenceService.loadConversation()
    }

    /// Save conversation to persistent storage
    func saveConversation() {
        persistenceService.saveConversation(messages)
    }

    /// Delete a specific message
    func deleteMessage(_ message: ChatMessage) {
        messages.removeAll { $0.id == message.id }
        saveConversation()
    }
}
