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
    @Published var conversations: [Conversation] = []
    @Published var currentConversationId: UUID?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var toolsUsed: [String] = []
    @Published var showingHistory: Bool = false

    private let agentKernel: AgentKernel
    private let persistenceService: ConversationPersistenceService

    var currentMessages: [ChatMessage] {
        guard let currentId = currentConversationId,
              let conversation = conversations.first(where: { $0.id == currentId }) else {
            return []
        }
        return conversation.messages
    }

    init(agentKernel: AgentKernel, persistenceService: ConversationPersistenceService = ConversationPersistenceService()) {
        self.agentKernel = agentKernel
        self.persistenceService = persistenceService
        loadConversations()

        // Create first conversation if none exist
        if conversations.isEmpty {
            createNewConversation()
        } else if currentConversationId == nil {
            currentConversationId = conversations.first?.id
        }
    }

    /// Send a message to the AI agent
    func sendMessage(_ text: String) async {
        guard !text.isEmpty, let currentId = currentConversationId else { return }
        guard let index = conversations.firstIndex(where: { $0.id == currentId }) else { return }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        conversations[index].messages.append(userMessage)
        conversations[index].updatedAt = Date()

        // Update title from latest message
        conversations[index].updateTitleFromLatestMessage()

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Convert to AgentMessage format (exclude tool-related messages)
            let history = conversations[index].messages.compactMap { $0.toAgentMessage() }

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
            conversations[index].messages.append(aiMessage)
            conversations[index].updatedAt = Date()
            conversations[index].updateTitleFromLatestMessage()
            toolsUsed = response.toolsUsed

            // Persist conversations
            saveConversations()

        } catch {
            self.error = error.localizedDescription
            // Remove the user message if we failed to get a response
            if conversations[index].messages.last?.id == userMessage.id {
                conversations[index].messages.removeLast()
            }
        }
    }

    /// Create a new conversation
    func createNewConversation() {
        let newConversation = Conversation()
        conversations.insert(newConversation, at: 0)
        currentConversationId = newConversation.id
        saveConversations()
    }

    /// Switch to a different conversation
    func switchConversation(id: UUID) {
        currentConversationId = id
        error = nil
        toolsUsed.removeAll()
    }

    /// Delete a conversation
    func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }

        // If we deleted the current conversation, switch to another one
        if currentConversationId == id {
            if let firstConversation = conversations.first {
                currentConversationId = firstConversation.id
            } else {
                // Create a new conversation if none left
                createNewConversation()
                return // createNewConversation already saves
            }
        }

        persistenceService.deleteConversation(id: id)
        saveConversations()
    }

    /// Load conversations from persistent storage
    func loadConversations() {
        conversations = persistenceService.loadConversations()
    }

    /// Save conversations to persistent storage
    func saveConversations() {
        // Sort by updated date before saving
        conversations.sort { $0.updatedAt > $1.updatedAt }
        persistenceService.saveConversations(conversations)
    }

    /// Delete a specific message from current conversation
    func deleteMessage(_ message: ChatMessage) {
        guard let currentId = currentConversationId,
              let index = conversations.firstIndex(where: { $0.id == currentId }) else { return }

        conversations[index].messages.removeAll { $0.id == message.id }
        conversations[index].updatedAt = Date()
        saveConversations()
    }
}
