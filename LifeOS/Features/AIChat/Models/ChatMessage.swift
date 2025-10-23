import Foundation

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let role: Role
    let content: String
    let toolsUsed: [String]
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, toolsUsed: [String] = [], timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.toolsUsed = toolsUsed
        self.timestamp = timestamp
    }
    func toAgentMessage() -> AgentMessage {
        switch role {
        case .user:
            return .user(content)
        case .assistant:
            return .assistant(content)
        }
    }
    static func from(_ agentMessage: AgentMessage, toolsUsed: [String] = []) -> ChatMessage? {
        switch agentMessage {
        case .user(let text):
            return ChatMessage(role: .user, content: text)
        case .assistant(let text):
            return ChatMessage(role: .assistant, content: text, toolsUsed: toolsUsed)
        case .toolCall, .toolResult:
            return nil
        }
    }
}
