import Foundation

class ConversationPersistenceService {
    private let userDefaults: UserDefaults
    private let storageKey = "ai_chat_conversation_history"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    func saveConversation(_ messages: [ChatMessage]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(messages)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("Error saving conversation: \(error)")
        }
    }
    func loadConversation() -> [ChatMessage] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let messages = try decoder.decode([ChatMessage].self, from: data)
            return messages
        } catch {
            print("Error loading conversation: \(error)")
            return []
        }
    }

    /// Clear all conversation history
    func clearConversation() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
