import Foundation

/// Protocol that all agent tools must implement
/// Tools are functions the AI agent can call to retrieve information from the journal system
protocol AgentTool {
    /// The name of the tool (e.g., "search_semantic", "get_month_summary")
    var name: String { get }

    /// Human-readable description of what the tool does
    /// This helps the AI understand when to use this tool
    var description: String { get }

    /// JSON Schema definition of the tool's parameters
    /// This is used by OpenAI's function calling API
    var parametersSchema: [String: Any] { get }

    /// Execute the tool with the given arguments
    /// - Parameter arguments: Dictionary of arguments matching the parametersSchema
    /// - Returns: The result of the tool execution (will be JSON-serialized for the AI)
    /// - Throws: If the tool execution fails
    func execute(arguments: [String: Any]) async throws -> Any
}

extension AgentTool {
    /// Convert this tool to OpenAI function calling format
    func toOpenAIFunction() -> [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parametersSchema
            ]
        ]
    }
}
