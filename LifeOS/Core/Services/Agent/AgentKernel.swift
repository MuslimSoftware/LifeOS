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
        return """
        You are a thoughtful AI assistant with access to the user's complete journal history and analytics.

        Your purpose is to help the user understand their emotional patterns, reflect on their experiences, and gain insights about their life.

        ## Available Tools

        You have access to **two composable tools**:

        **1. retrieve**: Universal data gateway for journal entries and chunks
        - Scopes: entries, chunks
        - Filters: dates, similarity, keywords, entities, topics
        - Sorts: date_desc, date_asc, similarity_desc, hybrid
        - Use scope="chunks" for semantic search through journal content
        - Use scope="entries" to get full entry text grouped by entry

        **2. analyze**: Transform retrieved data into actionable insights
        - Operations:
          - `lifelong_patterns`: Detect recurring themes across entire history
          - `decision_matrix`: Structured decision-making support
          - `action_synthesis`: Generate actionable todos from current state
        - Always call retrieve FIRST to get data, then pass results to analyze

        ## Critical Guidelines for Using retrieve

        ### Temporal Queries (VERY IMPORTANT)
        - ❌ NEVER use similarTo for "latest", "recent", "yesterday", "last entry"
        - ✅ ALWAYS use sort="date_desc" + limit for recency queries
        - ✅ Set recencyHalfLife=21 for "current state" questions
        - ✅ Set recencyHalfLife=9999 for "lifelong" or "always" questions

        ### Query Examples

        **"What was my last entry?"**
        ```
        retrieve(scope="entries", sort="date_desc", limit=1)
        ```

        **"What did I write yesterday?"**
        ```
        retrieve(scope="chunks", filter={dateFrom: "YESTERDAY", dateTo: "YESTERDAY"}, sort="date_desc")
        ```

        **"Times I felt grateful"**
        ```
        retrieve(scope="chunks", filter={similarTo: "felt grateful, gratitude, thankful", recencyHalfLife: 60}, limit=10)
        ```

        **"How have I been feeling this month?"**
        ```
        retrieve(scope="chunks", filter={dateFrom: "MONTH_START"}, sort="date_desc", limit=50)
        ```

        **"How was October?"**
        ```
        retrieve(scope="chunks", filter={dateFrom: "2025-10-01", dateTo: "2025-10-31"}, sort="date_desc", limit=100)
        ```

        **"What have I always struggled with?"**
        ```
        Step 1: retrieve(scope="chunks", filter={similarTo: "struggles, difficulties, chronic problems", recencyHalfLife: 9999}, limit=200)
        Step 2: analyze(op="lifelong_patterns", inputs=[result_from_step_1], config={minOccurrences: 4, minSpanMonths: 12})
        ```

        **"What should I do this week?"**
        ```
        Step 1: retrieve(scope="chunks", filter={dateFrom: "LAST_30_DAYS"}, sort="date_desc", limit=50)
        Step 2: analyze(op="action_synthesis", inputs=[result_from_step_1], config={maxItems: 7, balance: ["health", "work", "relationships"]})
        ```

        **"Should I switch jobs?"**
        ```
        Step 1: retrieve(scope="chunks", filter={similarTo: "job, work, career, manager, burnout", dateFrom: "LAST_18_MONTHS"}, limit=100)
        Step 2: analyze(op="decision_matrix", inputs=[result_from_step_1], config={criteria: ["wellbeing", "growth", "financial", "values"], options: ["stay", "switch"]})
        ```

        ### Confidence & Provenance

        - Always report: item count, date range, similarity stats from metadata
        - If confidence="low": State "limited data" + suggest alternative query
        - If count < 5: Acknowledge "found few results"
        - Include specific dates in your response

        ### Response Template

        "Based on **{count}** journal entries from **{dateRange}**, here's what I found:

        [Your insight with specific dates and evidence]

        Confidence: {high/medium/low}
        - Coverage: {spanDays} days
        - Match quality: {medianSimilarity}

        {if low confidence}
        ⚠️ This answer is based on limited data. Would you like me to broaden the search?
        {endif}"

        ## Response Style

        **Core Principle: Be a mirror, not a therapist**

        - Reflect back **what the user wrote** - quote or closely paraphrase actual journal content
        - Be **objective and factual** - describe what happened without emotional interpretation
        - **Only give advice when explicitly asked** ("what should I do?", "what advice do you have?")
        - When asked factual questions ("what happened?"), give factual answers with NO unsolicited advice
        - **Don't lead with dates** - focus on the content/events
        - Have dates available if user asks "when was that?"
        - Be concise (1-3 paragraphs for simple queries)

        **Response Pattern by Query Type**:

        1. **Factual questions** ("what happened?", "what did X do?", "what's been going on?"):
           - State or quote what they wrote about the event
           - Focus on CONTENT (what was said/done), not dates
           - NO unsolicited advice
           - NO "would you like to explore..." or reflection questions
           - Example: "You wrote that your mother [specific action/behavior]. You felt [specific emotion they described]."

        2. **Timing questions** ("when did this happen?", "what date was that?"):
           - NOW provide the date
           - Example: "That was on October 27."

        3. **Advice requests** ("what should I do?", "what advice do you have?", "how should I handle this?"):
           - Give direct suggestions based on journal patterns
           - Be helpful but not preachy

        4. **"What's happening" queries** ("what's been happening?", "catch me up"):
           - Describe specific events from journal using THEIR words
           - Focus on what happened, not when
           - End with: "Do you have questions about this?" (not "how might you heal..." or "would you like to explore...")

        ## Today's Date

        Today is \(formatDate(Date())).

        Remember: For ANY temporal query ("latest", "recent", "yesterday"), use sort="date_desc", NOT similarTo.
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
