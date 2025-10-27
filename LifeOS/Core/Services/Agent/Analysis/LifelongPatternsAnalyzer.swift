import Foundation

/// Analyzer for detecting lifelong recurring patterns
/// Identifies themes that appear repeatedly across the user's journal history
class LifelongPatternsAnalyzer {
    private let openAI: OpenAIService

    init(openAI: OpenAIService) {
        self.openAI = openAI
    }

    /// Analyze inputs for lifelong patterns
    /// - Parameters:
    ///   - inputs: Array of data (chunks, analytics) from retrieve calls
    ///   - config: Configuration with minOccurrences, minSpanMonths, requireRecurring
    /// - Returns: AnalysisResult with detected patterns
    func analyze(
        inputs: [[String: Any]],
        config: [String: Any]
    ) async throws -> AnalysisResult {
        let startTime = Date()

        // Extract configuration
        let minOccurrences = config["minOccurrences"] as? Int ?? 4
        let minSpanMonths = config["minSpanMonths"] as? Int ?? 12
        let requireRecurring = config["requireRecurring"] as? Bool ?? true

        // Prepare context from inputs
        let context = prepareContext(from: inputs)

        // Build analysis prompt
        let systemPrompt = buildSystemPrompt(
            minOccurrences: minOccurrences,
            minSpanMonths: minSpanMonths,
            requireRecurring: requireRecurring
        )

        let userPrompt = """
        Analyze the following journal data and analytics to identify lifelong recurring patterns.

        Journal data:
        \(context.journalSummary)

        Analytics summary:
        \(context.analyticsSummary)

        Identify patterns that:
        - Appear at least \(minOccurrences) times
        - Span at least \(minSpanMonths) months
        - \(requireRecurring ? "Show recurring behavior (not just a single extended period)" : "Can be single extended periods or recurring")

        For each pattern, identify:
        1. Pattern description
        2. First and last seen dates
        3. Number of occurrences/flare-ups
        4. Time span in months
        5. Specific flare-up windows (start/end dates)
        6. Triggers (what precedes the pattern)
        7. Protective factors (what helps resolve it)
        8. Supporting evidence count
        """

        // Call OpenAI with structured output
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]

        let schema = buildJSONSchema()

        let response: PatternAnalysisResponse
        do {
            response = try await openAI.chatCompletion(
                messages: messages,
                schema: schema,
                model: "gpt-4o"
            )
        } catch {
            print("❌ [LifelongPatterns] OpenAI call failed")
            print("   Error: \(error.localizedDescription)")
            throw error
        }

        // Build result
        let executionTime = Date().timeIntervalSince(startTime)
        let resultItems = response.patterns.map { pattern in
            AnalysisResult.AnalysisItem(
                id: nil,
                content: [
                    "pattern": pattern.pattern,
                    "firstSeen": pattern.firstSeen,
                    "lastSeen": pattern.lastSeen,
                    "occurrences": pattern.occurrences,
                    "spanMonths": pattern.spanMonths,
                    "flareUpWindows": pattern.flareUpWindows.map { window in
                        ["start": window.start, "end": window.end]
                    },
                    "triggers": pattern.triggers,
                    "protectiveFactors": pattern.protectiveFactors,
                    "confidence": pattern.confidence,
                    "supportingEvidenceCount": pattern.supportingEvidenceCount
                ]
            )
        }

        let confidence: AnalysisResult.AnalysisMetadata.Confidence
        if resultItems.count >= 3 && context.dataPointCount >= 50 {
            confidence = .high
        } else if resultItems.count >= 1 && context.dataPointCount >= 20 {
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
            operation: "lifelong_patterns",
            results: resultItems,
            metadata: metadata
        )
    }

    // MARK: - Private Helpers

    private struct Context {
        let journalSummary: String
        let analyticsSummary: String
        let dataPointCount: Int
    }

    private func prepareContext(from inputs: [[String: Any]]) -> Context {
        var journalTexts: [String] = []
        var analyticsPoints: [(date: String, metric: String, value: Double)] = []
        var totalItems = 0

        // Get recommended token budget for this operation
        let budget = TokenBudgetManager.recommendedBudget(for: "lifelong_patterns")

        for input in inputs {
            // Check if it's journal data (has items array)
            if let items = input["items"] as? [[String: Any]] {
                totalItems += items.count

                // Use TokenBudgetManager to dynamically select entries that fit budget
                let (selectedItems, estimatedTokens) = TokenBudgetManager.selectEntries(
                    from: items,
                    targetTokenBudget: budget,
                    systemPromptTokens: 1500  // Reserve for system prompt + response
                )

                // Log what we're about to send
                TokenBudgetManager.logBudgetInfo(
                    operation: "LifelongPatterns",
                    totalItems: totalItems,
                    selectedItems: selectedItems.count,
                    estimatedTokens: estimatedTokens,
                    budget: budget
                )

                for item in selectedItems {
                    if let text = item["text"] as? String, !text.isEmpty {
                        let date = item["date"] as? String ?? "unknown"
                        // Keep entries COMPLETE - no truncation
                        journalTexts.append("[\(date)] \(text)")
                    }

                    // Extract analytics if present
                    if let scoreComponents = item["scoreComponents"] as? [String: Any],
                       let magnitude = scoreComponents["magnitude"] as? Double {
                        let date = item["date"] as? String ?? "unknown"
                        analyticsPoints.append((date: date, metric: "value", value: magnitude))
                    }
                }
            }
        }

        // Build journal summary
        let journalSummary: String
        if journalTexts.isEmpty {
            journalSummary = "No journal text provided"
        } else {
            journalSummary = journalTexts.joined(separator: "\n\n")
        }

        // Summarize analytics
        let analyticsSummary: String
        if analyticsPoints.isEmpty {
            analyticsSummary = "No analytics data provided"
        } else {
            let summary = "Total data points: \(analyticsPoints.count)"
            analyticsSummary = summary
        }

        return Context(
            journalSummary: journalSummary,
            analyticsSummary: analyticsSummary,
            dataPointCount: journalTexts.count + analyticsPoints.count
        )
    }

    private func buildSystemPrompt(
        minOccurrences: Int,
        minSpanMonths: Int,
        requireRecurring: Bool
    ) -> String {
        return """
        You are a psychological pattern analyst specializing in identifying long-term behavioral and emotional patterns from journal data.

        Your task is to analyze journal entries and identify **recurring patterns** that:
        - Appear at least \(minOccurrences) distinct times
        - Span at least \(minSpanMonths) months from first to last occurrence
        - \(requireRecurring ? "Show true recurring behavior (not just one extended period)" : "Can be either recurring episodes or extended periods")

        For each pattern you identify:
        1. **Pattern**: Clear description of the recurring theme
        2. **First seen**: Earliest date this pattern appeared (YYYY-MM-DD format)
        3. **Last seen**: Most recent date this pattern appeared (YYYY-MM-DD format)
        4. **Occurrences**: How many distinct times/episodes this pattern appeared
        5. **Span months**: Total months from first to last seen
        6. **Flare-up windows**: Specific time periods when this pattern was active (array of start/end dates)
        7. **Triggers**: What tends to precede or cause this pattern (array of strings)
        8. **Protective factors**: What helps prevent or resolve this pattern (array of strings)
        9. **Confidence**: Your confidence level (high/medium/low)
        10. **Supporting evidence count**: How many journal entries support this pattern

        Focus on:
        - Mental health patterns (depression cycles, anxiety triggers, burnout)
        - Behavioral patterns (social withdrawal, workaholism, self-care lapses)
        - Relationship patterns (conflict cycles, attachment styles)
        - Life transitions (career changes, relationship changes)

        Be evidence-based. Only report patterns you can clearly identify in the data.
        """
    }

    private func buildJSONSchema() -> [String: Any] {
        return [
            "name": "lifelong_patterns_response",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "patterns": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "pattern": ["type": "string"],
                                "firstSeen": ["type": "string"],
                                "lastSeen": ["type": "string"],
                                "occurrences": ["type": "integer"],
                                "spanMonths": ["type": "integer"],
                                "flareUpWindows": [
                                    "type": "array",
                                    "items": [
                                        "type": "object",
                                        "properties": [
                                            "start": ["type": "string"],
                                            "end": ["type": "string"]
                                        ],
                                        "required": ["start", "end"],
                                        "additionalProperties": false
                                    ]
                                ],
                                "triggers": [
                                    "type": "array",
                                    "items": ["type": "string"]
                                ],
                                "protectiveFactors": [
                                    "type": "array",
                                    "items": ["type": "string"]
                                ],
                                "confidence": [
                                    "type": "string",
                                    "enum": ["high", "medium", "low"]
                                ],
                                "supportingEvidenceCount": ["type": "integer"]
                            ],
                            "required": [
                                "pattern", "firstSeen", "lastSeen", "occurrences",
                                "spanMonths", "flareUpWindows", "triggers",
                                "protectiveFactors", "confidence", "supportingEvidenceCount"
                            ],
                            "additionalProperties": false
                        ]
                    ]
                ],
                "required": ["patterns"],
                "additionalProperties": false
            ]
        ]
    }
}

// MARK: - Response Models

private struct PatternAnalysisResponse: Codable {
    let patterns: [Pattern]

    struct Pattern: Codable {
        let pattern: String
        let firstSeen: String
        let lastSeen: String
        let occurrences: Int
        let spanMonths: Int
        let flareUpWindows: [FlareUpWindow]
        let triggers: [String]
        let protectiveFactors: [String]
        let confidence: String
        let supportingEvidenceCount: Int
    }

    struct FlareUpWindow: Codable {
        let start: String
        let end: String
    }
}
