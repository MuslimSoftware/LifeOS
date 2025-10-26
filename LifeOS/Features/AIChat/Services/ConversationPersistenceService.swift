import Foundation

class ConversationPersistenceService {
    private let userDefaults: UserDefaults
    private let storageKey = "ai_chat_conversations"
    private let legacyStorageKey = "ai_chat_conversation_history"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        migrateLegacyConversation()
    }

    /// Migrate old single conversation to new multi-conversation format
    private func migrateLegacyConversation() {
        // Check if there's old data and no new data
        guard userDefaults.data(forKey: storageKey) == nil,
              let legacyData = userDefaults.data(forKey: legacyStorageKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let messages = try decoder.decode([ChatMessage].self, from: legacyData)

            if !messages.isEmpty {
                var conversation = Conversation(messages: messages)
                conversation.updateTitleFromLatestMessage()
                saveConversations([conversation])
            }

            // Remove legacy data
            userDefaults.removeObject(forKey: legacyStorageKey)
        } catch {
            print("Error migrating legacy conversation: \(error)")
        }
    }

    func saveConversations(_ conversations: [Conversation]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conversations)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("Error saving conversations: \(error)")
        }
    }

    func loadConversations() -> [Conversation] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let conversations = try decoder.decode([Conversation].self, from: data)
            return conversations.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Error loading conversations: \(error)")
            return []
        }
    }

    func deleteConversation(id: UUID) {
        var conversations = loadConversations()
        conversations.removeAll { $0.id == id }
        saveConversations(conversations)
    }

    /// Clear all conversations
    func clearAllConversations() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
