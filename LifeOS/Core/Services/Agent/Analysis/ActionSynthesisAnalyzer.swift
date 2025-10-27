import Foundation

/// Analyzer for generating actionable todos from current state
/// Synthesizes journal data and analytics into concrete next steps
class ActionSynthesisAnalyzer {
    private let openAI: OpenAIService

    init(openAI: OpenAIService) {
        self.openAI = openAI
    }

    /// Analyze inputs to generate actionable todos
    /// - Parameters:
    ///   - inputs: Array of data (recent analytics, summaries, themes)
    ///   - config: Configuration with maxItems, balance, includeFirstStep
    /// - Returns: AnalysisResult with actionable todos
    func analyze(
        inputs: [[String: Any]],
        config: [String: Any]
    ) async throws -> AnalysisResult {
        let startTime = Date()

        // Extract configuration
        let maxItems = config["maxItems"] as? Int ?? 7
        let balance = config["balance"] as? [String] ?? ["health", "work", "relationships"]
        let includeFirstStep = config["includeFirstStep"] as? Bool ?? true

        // Prepare context from inputs
        let context = prepareContext(from: inputs)

        // Build analysis prompt
        let systemPrompt = buildSystemPrompt(
            maxItems: maxItems,
            balance: balance,
            includeFirstStep: includeFirstStep
        )

        let userPrompt = """
        Based on the user's recent journal entries and analytics, generate actionable todos for the coming week.

        Recent themes and concerns:
        \(context.themesSummary)

        Current wellbeing metrics:
        \(context.metricsSummary)

        Recent entries:
        \(context.journalSummary)

        Generate \(maxItems) actionable todos that:
        - Address the most pressing concerns identified in the journal
        - Are balanced across these life areas: \(balance.joined(separator: ", "))
        - Are specific, concrete, and achievable within a week
        - Include a clear first step (no more than 30 minutes)
        - Explain why each action matters based on journal evidence
        - Estimate effort (time) and potential impact (high/medium/low)
        """

        // Call OpenAI with structured output
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]

        let schema = buildJSONSchema()

        let response: ActionSynthesisResponse
        do {
            response = try await openAI.chatCompletion(
                messages: messages,
                schema: schema,
                model: "gpt-4o"
            )
        } catch {
            print("❌ [ActionSynthesis] OpenAI call failed")
            print("   Error: \(error.localizedDescription)")
            throw error
        }

        // Build result
        let executionTime = Date().timeIntervalSince(startTime)

        let resultItems = response.actions.map { action in
            var content: [String: Any] = [
                "action": action.action,
                "category": action.category,
                "whyItMatters": action.whyItMatters,
                "estimatedMinutes": action.estimatedMinutes,
                "impact": action.impact,
                "urgency": action.urgency
            ]

            if let firstStep = action.firstStep {
                content["firstStep"] = firstStep
            }

            if let evidence = action.supportingEvidence {
                content["supportingEvidence"] = evidence
            }

            return AnalysisResult.AnalysisItem(id: nil, content: content)
        }

        let confidence: AnalysisResult.AnalysisMetadata.Confidence
        if context.dataPointCount >= 20 && !context.metricsSummary.isEmpty {
            confidence = .high
        } else if context.dataPointCount >= 5 {
            confidence = .medium
        } else {
            confidence = .low
        }

        let metadata = AnalysisResult.AnalysisMetadata(
            executionTimeSeconds: executionTime,
            model: "gpt-4o",
            tokensUsed: nil,
            confidence: confidence
        )

        return AnalysisResult(
            operation: "action_synthesis",
            results: resultItems,
            metadata: metadata
        )
    }

    // MARK: - Private Helpers

    private struct Context {
        let themesSummary: String
        let metricsSummary: String
        let journalSummary: String
        let dataPointCount: Int
    }

    private func prepareContext(from inputs: [[String: Any]]) -> Context {
        var recentTexts: [String] = []
        var themes: [String: Int] = [:]
        var metricsData: [String: Double] = [:]
        var totalItems = 0

        // Get recommended token budget for this operation (smaller - recent only)
        let budget = TokenBudgetManager.recommendedBudget(for: "action_synthesis")

        for input in inputs {
            if let items = input["items"] as? [[String: Any]] {
                totalItems += items.count

                // Use TokenBudgetManager to dynamically select entries that fit budget
                let (selectedItems, estimatedTokens) = TokenBudgetManager.selectEntries(
                    from: items,
                    targetTokenBudget: budget,
                    systemPromptTokens: 800  // Reserve for system prompt + response (smaller)
                )

                // Log what we're about to send
                TokenBudgetManager.logBudgetInfo(
                    operation: "ActionSynthesis",
                    totalItems: totalItems,
                    selectedItems: selectedItems.count,
                    estimatedTokens: estimatedTokens,
                    budget: budget
                )

                for item in selectedItems {
                    // Journal text
                    if let text = item["text"] as? String, !text.isEmpty {
                        let date = item["date"] as? String ?? "unknown"
                        // Keep entries COMPLETE - no truncation
                        recentTexts.append("[\(date)] \(text)")

                        // Extract themes (simple word frequency for common emotional words)
                        let emotionalKeywords = ["stress", "anxious", "tired", "happy", "grateful", "frustrated", "overwhelmed", "lonely", "excited", "worried"]
                        for keyword in emotionalKeywords {
                            if text.localizedCaseInsensitiveContains(keyword) {
                                themes[keyword, default: 0] += 1
                            }
                        }
                    }

                    // Metrics
                    if let scoreComponents = item["scoreComponents"] as? [String: Any],
                       let magnitude = scoreComponents["magnitude"] as? Double {
                        metricsData["averageWellbeing"] = (metricsData["averageWellbeing"] ?? 0) + magnitude
                    }
                }
            }
        }

        // Normalize metrics
        if let wellbeingSum = metricsData["averageWellbeing"], wellbeingSum > 0 {
            let count = Double(recentTexts.count)
            metricsData["averageWellbeing"] = (wellbeingSum / count) * 100
        }

        // Sort themes by frequency
        let sortedThemes = themes.sorted { $0.value > $1.value }.prefix(5)

        // Build summaries
        let themesSummary: String
        if sortedThemes.isEmpty {
            themesSummary = "No clear themes identified"
        } else {
            themesSummary = sortedThemes.map { "\($0.key) (mentioned \($0.value) times)" }.joined(separator: ", ")
        }

        let metricsSummary: String
        if let avgWellbeing = metricsData["averageWellbeing"] {
            metricsSummary = "Average wellbeing: \(String(format: "%.1f", avgWellbeing))/100"
        } else {
            metricsSummary = "No wellbeing metrics available"
        }

        let journalSummary: String
        if recentTexts.isEmpty {
            journalSummary = "No recent journal entries"
        } else {
            // Already selected by TokenBudgetManager - use all
            journalSummary = recentTexts.joined(separator: "\n\n")
        }

        return Context(
            themesSummary: themesSummary,
            metricsSummary: metricsSummary,
            journalSummary: journalSummary,
            dataPointCount: recentTexts.count
        )
    }

    private func buildSystemPrompt(
        maxItems: Int,
        balance: [String],
        includeFirstStep: Bool
    ) -> String {
        return """
        You are a thoughtful life coach helping someone translate self-reflection into concrete action.

        Your task is to analyze recent journal entries and current wellbeing data, then generate **\(maxItems) actionable todos** for the coming week.

        Each action should:
        1. **Address a real need** identified in the journal (not generic advice)
        2. **Be specific and concrete** (not vague like "exercise more")
        3. **Be achievable within 1 week** (break large goals into small steps)
        4. **Balanced across**: \(balance.joined(separator: ", "))
        \(includeFirstStep ? "5. **Include a first step** that takes no more than 30 minutes" : "")
        6. **Explain why it matters** based on journal evidence
        7. **Estimate effort** (time in minutes)
        8. **Estimate impact** (high/medium/low on wellbeing)
        9. **Assess urgency** (high/medium/low)

        Guidelines:
        - Prioritize actions that address recurring problems or declining metrics
        - Consider the person's current energy level and capacity
        - Suggest proactive/preventive actions, not just reactive ones
        - Make first steps as concrete as possible (e.g., "Call Dr. Smith's office at 9am Monday")
        - Reference specific journal entries to show why each action is relevant
        - Balance quick wins (low effort, medium impact) with important work (high effort, high impact)

        Be supportive and realistic. Don't overwhelm with too many high-effort items.
        """
    }

    private func buildJSONSchema() -> [String: Any] {
        return [
            "name": "action_synthesis_response",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "actions": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "action": ["type": "string"],
                                "category": [
                                    "type": "string",
                                    "enum": ["health", "work", "relationships", "personal_growth", "leisure"]
                                ],
                                "firstStep": ["type": "string"],
                                "whyItMatters": ["type": "string"],
                                "estimatedMinutes": ["type": "integer"],
                                "impact": [
                                    "type": "string",
                                    "enum": ["high", "medium", "low"]
                                ],
                                "urgency": [
                                    "type": "string",
                                    "enum": ["high", "medium", "low"]
                                ],
                                "supportingEvidence": ["type": "string"]
                            ],
                            "required": ["action", "category", "firstStep", "whyItMatters", "estimatedMinutes", "impact", "urgency"],
                            "additionalProperties": false
                        ]
                    ]
                ],
                "required": ["actions"],
                "additionalProperties": false
            ]
        ]
    }
}

// MARK: - Response Models

private struct ActionSynthesisResponse: Codable {
    let actions: [Action]

    struct Action: Codable {
        let action: String
        let category: String
        let firstStep: String?
        let whyItMatters: String
        let estimatedMinutes: Int
        let impact: String
        let urgency: String
        let supportingEvidence: String?
    }
}
