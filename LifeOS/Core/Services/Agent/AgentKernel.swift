import Foundation

/// The main agent kernel implementing the ReAct (Reasoning + Acting) loop
class AgentKernel {
    private let openAI: OpenAIService
    private let toolRegistry: ToolRegistry
    private let maxIterations: Int
    private let model: String

    init(
        openAI: OpenAIService,
        toolRegistry: ToolRegistry,
        maxIterations: Int = 10,
        model: String = "gpt-4o"
    ) {
        self.openAI = openAI
        self.toolRegistry = toolRegistry
        self.maxIterations = maxIterations
        self.model = model
    }

    /// Run the agent with a user message
    /// - Parameters:
    ///   - userMessage: The user's question or request
    ///   - conversationHistory: Previous conversation history (for context)
    /// - Returns: The agent's response
    func runAgent(
        userMessage: String,
        conversationHistory: [AgentMessage] = []
    ) async throws -> AgentResponse {
        let startTime = Date()
        var messages = conversationHistory
        messages.append(.user(userMessage))

        var iteration = 0
        var toolsUsed: Set<String> = []
        var totalPromptTokens = 0
        var totalCompletionTokens = 0

        // ReAct loop: Reason → Act → Observe
        while iteration < maxIterations {
            iteration += 1

            // Build messages for OpenAI API
            let openAIMessages = messages.map { $0.toOpenAIMessage() }

            // Add system prompt at the beginning
            var allMessages: [[String: Any]] = [
                ["role": "system", "content": Self.buildSystemPrompt()]
            ]
            allMessages.append(contentsOf: openAIMessages)

            // Call OpenAI with tools
            let response = try await openAI.chatCompletionWithTools(
                messages: allMessages,
                tools: toolRegistry.getToolSchemas(),
                model: model
            )

            // Track token usage (rough estimate)
            totalPromptTokens += estimateTokens(allMessages)
            if let content = response.content {
                totalCompletionTokens += estimateTokens(content)
            }

            // Check if the model wants to use tools
            if response.hasToolCalls, let toolCalls = response.toolCalls {
                // Process each tool call
                for toolCall in toolCalls {
                    toolsUsed.insert(toolCall.name)

                    // Add the tool call to conversation
                    messages.append(.toolCall(toolCall.id, toolCall))

                    // Parse arguments
                    let arguments: [String: Any]
                    if let jsonData = toolCall.arguments.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        arguments = parsed
                    } else {
                        arguments = [:]
                    }

                    // Execute the tool
                    do {
                        let result = try await toolRegistry.executeTool(
                            name: toolCall.name,
                            arguments: arguments
                        )

                        // Serialize result to JSON
                        let jsonData = try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
                        let resultString = String(data: jsonData, encoding: .utf8) ?? "{}"

                        // Add tool result to conversation
                        messages.append(.toolResult(toolCall.id, toolCall.name, resultString))

                    } catch {
                        // Tool execution failed - send error to model
                        let errorResult = [
                            "error": error.localizedDescription,
                            "tool": toolCall.name
                        ]
                        let jsonData = try JSONSerialization.data(withJSONObject: errorResult)
                        let resultString = String(data: jsonData, encoding: .utf8) ?? "{}"

                        messages.append(.toolResult(toolCall.id, toolCall.name, resultString))
                    }
                }

                // Continue the loop - model will see tool results and decide next step
                continue

            } else if let content = response.content, !content.isEmpty {
                // Model returned a final text response (no tool calls)
                messages.append(.assistant(content))

                // Calculate duration
                let duration = Date().timeIntervalSince(startTime)

                // Build response
                return AgentResponse(
                    text: content,
                    toolsUsed: Array(toolsUsed),
                    metadata: ResponseMetadata(
                        iterations: iteration,
                        durationSeconds: duration,
                        model: model,
                        estimatedTokens: TokenUsage(
                            promptTokens: totalPromptTokens,
                            completionTokens: totalCompletionTokens,
                            totalTokens: totalPromptTokens + totalCompletionTokens
                        ),
                        hitMaxIterations: false
                    )
                )
            } else {
                // No content and no tool calls - shouldn't happen, but handle it
                throw AgentError.invalidResponse("Model returned no content or tool calls")
            }
        }

        // Hit max iterations without final response
        let duration = Date().timeIntervalSince(startTime)
        return AgentResponse(
            text: "I apologize, but I've reached my processing limit for this query. Could you try rephrasing your question?",
            toolsUsed: Array(toolsUsed),
            metadata: ResponseMetadata(
                iterations: iteration,
                durationSeconds: duration,
                model: model,
                estimatedTokens: TokenUsage(
                    promptTokens: totalPromptTokens,
                    completionTokens: totalCompletionTokens,
                    totalTokens: totalPromptTokens + totalCompletionTokens
                ),
                hitMaxIterations: true
            )
        )
    }

    // MARK: - Private Helpers

    private static func buildSystemPrompt() -> String {
        return """
        You are a thoughtful AI assistant with access to the user's complete journal history and analytics.

        Your purpose is to help the user understand their emotional patterns, reflect on their experiences, and gain insights about their life.

        ## Available Tools

        You have access to the following tools:

        1. **search_semantic**: Search through journal entries using natural language
           - Use when the user asks about past experiences, feelings, or memories
           - Example: "When did I last feel anxious about work?"

        2. **get_month_summary**: Get AI-generated summary for a specific month
           - Use when the user asks about "how was [month]" or wants an overview
           - Returns narrative, positive/negative drivers, top events, happiness stats

        3. **get_year_summary**: Get year-in-review summary
           - Use for annual reflections or "how was [year]"

        4. **get_time_series**: Get happiness/stress/energy trends over time
           - Use when user asks about trends, patterns, or "how have I been feeling"
           - Can show happiness, stress, or energy metrics

        5. **get_current_state**: Analyze current life state with themes, mood, and suggested actions
           - Use when user asks "how am I doing?" or wants actionable advice
           - Returns themes, stressors, protective factors, and AI-suggested todos

        ## Guidelines

        - Be warm, empathetic, and non-judgmental
        - Use tools proactively to provide evidence-based insights
        - When sharing journal excerpts, be respectful and thoughtful
        - Provide actionable suggestions when appropriate
        - If uncertain, use semantic search to find relevant context
        - Keep responses concise but insightful (2-4 paragraphs)
        - Use specific examples and data from the journal when available

        ## Response Style

        - Start with empathy and understanding
        - Support claims with specific evidence (dates, events, metrics)
        - End with reflection questions or gentle suggestions when appropriate
        - Avoid being preachy or prescriptive
        - Use markdown formatting for better readability when appropriate

        ## Today's Date

        Today is \(formatDate(Date())).
        """
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func estimateTokens(_ messages: [[String: Any]]) -> Int {
        // Rough estimate: 1 token ≈ 4 characters
        let totalChars = messages.compactMap { message -> Int? in
            if let content = message["content"] as? String {
                return content.count
            }
            return nil
        }.reduce(0, +)

        return totalChars / 4
    }

    private func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }
}

// MARK: - Errors

enum AgentError: Error, LocalizedError {
    case invalidResponse(String)
    case maxIterationsExceeded
    case toolExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let message):
            return "Invalid response from AI: \(message)"
        case .maxIterationsExceeded:
            return "Agent exceeded maximum iterations"
        case .toolExecutionFailed(let message):
            return "Tool execution failed: \(message)"
        }
    }
}
