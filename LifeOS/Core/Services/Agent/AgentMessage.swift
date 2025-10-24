import Foundation

/// Represents a message in the agent conversation
enum AgentMessage: Codable {
    case user(String)
    case assistant(String)
    case toolCall(String, ToolCall) // (call ID, tool call details)
    case toolResult(String, String, String) // (call ID, tool name, result as JSON string)

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type, content, toolCallId, toolCall, toolName, result
    }

    enum MessageType: String, Codable {
        case user, assistant, toolCall, toolResult
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .user:
            let content = try container.decode(String.self, forKey: .content)
            self = .user(content)
        case .assistant:
            let content = try container.decode(String.self, forKey: .content)
            self = .assistant(content)
        case .toolCall:
            let callId = try container.decode(String.self, forKey: .toolCallId)
            let toolCall = try container.decode(ToolCall.self, forKey: .toolCall)
            self = .toolCall(callId, toolCall)
        case .toolResult:
            let callId = try container.decode(String.self, forKey: .toolCallId)
            let toolName = try container.decode(String.self, forKey: .toolName)
            let result = try container.decode(String.self, forKey: .result)
            self = .toolResult(callId, toolName, result)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .user(let content):
            try container.encode(MessageType.user, forKey: .type)
            try container.encode(content, forKey: .content)
        case .assistant(let content):
            try container.encode(MessageType.assistant, forKey: .type)
            try container.encode(content, forKey: .content)
        case .toolCall(let callId, let toolCall):
            try container.encode(MessageType.toolCall, forKey: .type)
            try container.encode(callId, forKey: .toolCallId)
            try container.encode(toolCall, forKey: .toolCall)
        case .toolResult(let callId, let toolName, let result):
            try container.encode(MessageType.toolResult, forKey: .type)
            try container.encode(callId, forKey: .toolCallId)
            try container.encode(toolName, forKey: .toolName)
            try container.encode(result, forKey: .result)
        }
    }

    // MARK: - OpenAI Conversion

    /// Convert to OpenAI API message format
    func toOpenAIMessage() -> [String: Any] {
        switch self {
        case .user(let content):
            return [
                "role": "user",
                "content": content
            ]

        case .assistant(let content):
            return [
                "role": "assistant",
                "content": content
            ]

        case .toolCall(let callId, let toolCall):
            // OpenAI API requires arguments to be a JSON string, not an object
            let argumentsString: String
            if let argumentsData = try? JSONSerialization.data(withJSONObject: toolCall.arguments),
               let string = String(data: argumentsData, encoding: .utf8) {
                argumentsString = string
            } else {
                argumentsString = "{}" // Fallback to empty object
            }

            return [
                "role": "assistant",
                "content": NSNull(),
                "tool_calls": [
                    [
                        "id": callId,
                        "type": "function",
                        "function": [
                            "name": toolCall.name,
                            "arguments": argumentsString
                        ]
                    ]
                ]
            ]

        case .toolResult(let callId, let toolName, let result):
            return [
                "role": "tool",
                "tool_call_id": callId,
                "name": toolName,
                "content": result
            ]
        }
    }

    /// Create from OpenAI response
    static func fromOpenAIResponse(content: String?, toolCalls: [ToolCall]?) -> [AgentMessage] {
        var messages: [AgentMessage] = []

        // If there's text content, add it as assistant message
        if let content = content, !content.isEmpty {
            messages.append(.assistant(content))
        }

        // If there are tool calls, add them
        if let toolCalls = toolCalls {
            for toolCall in toolCalls {
                messages.append(.toolCall(toolCall.id, toolCall))
            }
        }

        return messages
    }

    // MARK: - Helpers

    /// Get the display text for this message (for UI)
    var displayText: String {
        switch self {
        case .user(let content):
            return content
        case .assistant(let content):
            return content
        case .toolCall(_, let toolCall):
            return "[Calling tool: \(toolCall.name)]"
        case .toolResult(_, let toolName, _):
            return "[Result from: \(toolName)]"
        }
    }

    /// Get the role for this message
    var role: String {
        switch self {
        case .user: return "user"
        case .assistant: return "assistant"
        case .toolCall: return "assistant"
        case .toolResult: return "tool"
        }
    }

    /// Check if this is a user message
    var isUserMessage: Bool {
        if case .user = self { return true }
        return false
    }

    /// Check if this is an assistant message
    var isAssistantMessage: Bool {
        if case .assistant = self { return true }
        return false
    }
}
