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

                    // Arguments are already parsed as dictionary
                    let arguments = toolCall.arguments

                    // Execute the tool
                    do {
                        let result = try await toolRegistry.executeTool(
                            name: toolCall.name,
                            arguments: arguments
                        )

                        // Check if this is a retrieve result that should be cached
                        // Cache chunks/analytics but NOT summaries (summaries should be sent in full)
                        let resultToSend: Any
                        if let resultDict = result as? [String: Any],
                           let items = resultDict["items"] as? [[String: Any]],
                           resultDict["metadata"] != nil,
                           !items.isEmpty {

                            // Check if this is a summary result (don't cache these)
                            if let firstItem = items.first,
                               let provenance = firstItem["provenance"] as? [String: Any],
                               let source = provenance["source"] as? String,
                               source == "summaries" {
                                // Summaries should be sent in full, not cached
                                resultToSend = result
                                print("📊 [AgentKernel] Sending summary result in full (not cached)")
                            } else {
                                // This is chunks/analytics - cache it
                                let resultId = ResultCacheService.shared.store(result: result)
                                resultToSend = createRetrieveSummary(result: resultDict, resultId: resultId)
                                print("💾 [AgentKernel] Cached retrieve result '\(resultId)' (full data preserved for analyze)")
                            }
                        } else {
                            // Regular result - send as-is
                            resultToSend = result
                        }

                        // Serialize result to JSON
                        let jsonData = try JSONSerialization.data(withJSONObject: resultToSend, options: .prettyPrinted)
                        let resultString = String(data: jsonData, encoding: .utf8) ?? "{}"

                        // Log the full JSON being sent to LLM for debugging
                        print("📤 [AgentKernel] Sending tool result to LLM:")
                        print("Tool: \(toolCall.name)")
                        print("Result JSON (\(resultString.count) chars):")
                        if resultString.count < 2000 {
                            print(resultString)  // Print full if small
                        } else {
                            print(String(resultString.prefix(2000)) + "\n... (truncated, total: \(resultString.count) chars)")
                        }
                        print("---")

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
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let todayStr = dateFormatter.string(from: Date())

        return """
        You are an AI assistant with access to the user's journal history and analytics.

        Today's date: \(todayStr)

        ## Your Capabilities

        You can help users understand their journal entries through:
        - Semantic search across their complete journal history
        - Pattern detection in recurring themes and experiences
        - Decision-making support based on their past reflections
        - Actionable insights derived from their journal data

        ## Available Tools

        **retrieve** - Query journal entries and chunks
        - Filter by: date range, entities (people/places/projects), topics, sentiment, metrics, semantic similarity, or keywords
        - Sort by: date, similarity, magnitude, or hybrid ranking
        - View modes: raw, timeline, stats, histogram
        - Returns: Matching entries/chunks with metadata and similarity scores

        **analyze** - Transform retrieved data into insights
        - lifelong_patterns: Detect recurring themes across entire history
        - decision_matrix: Create structured decision evaluations
        - action_synthesis: Generate actionable next steps from current state

        Use these tools to provide the user with accurate, data-driven insights from their own journal entries.
        """
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

    /// Create a lightweight summary of retrieve results for agent reasoning
    /// Full data is cached and can be retrieved via resultId
    private func createRetrieveSummary(result: [String: Any], resultId: String) -> [String: Any] {
        var summary: [String: Any] = [
            "resultId": resultId
        ]

        // Extract metadata
        if let metadata = result["metadata"] as? [String: Any] {
            summary["metadata"] = metadata
            if let count = metadata["count"] as? Int {
                summary["count"] = count
            }
        }

        // Extract items for preview (first 2 items, truncated)
        if let items = result["items"] as? [[String: Any]] {
            let previewItems = items.prefix(2).map { item -> [String: Any] in
                var preview: [String: Any] = [:]
                if let id = item["id"] {
                    preview["id"] = id
                }
                if let date = item["date"] {
                    preview["date"] = date
                }
                if let score = item["score"] {
                    preview["score"] = score
                }
                // Truncate text for preview
                if let text = item["text"] as? String {
                    let maxChars = 150
                    preview["textPreview"] = String(text.prefix(maxChars)) + (text.count > maxChars ? "..." : "")
                }
                return preview
            }
            summary["preview"] = previewItems
        }

        summary["note"] = "Full data cached with ID '\(resultId)'. To analyze, call: analyze(op=\"...\", inputs=[\"\(resultId)\"], config={...})"

        return summary
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
