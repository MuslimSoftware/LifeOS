import Foundation
import GRDB

class ConversationPersistenceService {
    private let conversationRepo: ConversationRepository
    private let userDefaults: UserDefaults
    private let legacyStorageKey = "ai_chat_conversation_history"

    init(conversationRepo: ConversationRepository = ConversationRepository(), userDefaults: UserDefaults = .standard) {
        self.conversationRepo = conversationRepo
        self.userDefaults = userDefaults
        migrateLegacyConversation()
    }

    private func migrateLegacyConversation() {
        guard let legacyData = userDefaults.data(forKey: legacyStorageKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let messages = try decoder.decode([ChatMessage].self, from: legacyData)

            if !messages.isEmpty {
                var conversation = Conversation(messages: messages)
                conversation.updateTitleFromLatestMessage()
                try conversationRepo.save(conversation)
            }

            userDefaults.removeObject(forKey: legacyStorageKey)
        } catch {
            print("Error migrating legacy conversation: \(error)")
        }
    }

    func saveConversations(_ conversations: [Conversation]) {
        do {
            for conversation in conversations {
                try conversationRepo.save(conversation)
            }
        } catch {
            print("Error saving conversations: \(error)")
        }
    }

    func loadConversations() -> [Conversation] {
        do {
            return try conversationRepo.getAllConversations()
        } catch {
            print("Error loading conversations: \(error)")
            return []
        }
    }

    func deleteConversation(id: UUID) {
        do {
            try conversationRepo.delete(id: id)
        } catch {
            print("Error deleting conversation: \(error)")
        }
    }

    func clearAllConversations() {
        do {
            let conversations = try conversationRepo.getAllConversations()
            for conversation in conversations {
                try conversationRepo.delete(id: conversation.id)
            }
        } catch {
            print("Error clearing conversations: \(error)")
        }
    }
}
