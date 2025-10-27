import Foundation

/// Analyzer for structured decision-making support
/// Creates a criteria-based decision matrix to help evaluate options
class DecisionMatrixAnalyzer {
    private let openAI: OpenAIService

    init(openAI: OpenAIService) {
        self.openAI = openAI
    }

    /// Analyze inputs for decision-making
    /// - Parameters:
    ///   - inputs: Array of data (journal chunks, analytics) related to the decision
    ///   - config: Configuration with criteria, options, includeCounterfactuals
    /// - Returns: AnalysisResult with decision matrix
    func analyze(
        inputs: [[String: Any]],
        config: [String: Any]
    ) async throws -> AnalysisResult {
        let startTime = Date()

        // Extract configuration
        let criteria = config["criteria"] as? [String] ?? ["wellbeing", "growth", "financial", "values", "risk"]
        let options = config["options"] as? [String] ?? []
        let includeCounterfactuals = config["includeCounterfactuals"] as? Bool ?? false

        guard !options.isEmpty else {
            return AnalysisResult.empty(operation: "decision_matrix", reason: "No options provided")
        }

        // Prepare context from inputs
        let context = prepareContext(from: inputs)

        // Build analysis prompt
        let systemPrompt = buildSystemPrompt(
            criteria: criteria,
            options: options,
            includeCounterfactuals: includeCounterfactuals
        )

        let userPrompt = """
        Analyze the following journal data to help make a decision between these options: \(options.joined(separator: ", "))

        Journal context:
        \(context.journalSummary)

        Analytics context:
        \(context.analyticsSummary)

        Create a decision matrix evaluating each option against these criteria: \(criteria.joined(separator: ", "))

        For each option, provide:
        1. Overall score (0-10) for each criterion
        2. Supporting evidence from the journal
        3. Key pros and cons
        4. Potential risks

        \(includeCounterfactuals ? "Also include a counterfactual analysis: What would have happened if a similar decision was made differently in the past?" : "")

        Be objective and evidence-based. Use specific quotes and dates from the journal.
        """

        // Call OpenAI with structured output
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]

        let schema = buildJSONSchema(criteria: criteria, options: options)

        let response: DecisionMatrixResponse
        do {
            response = try await openAI.chatCompletion(
                messages: messages,
                schema: schema,
                model: "gpt-4o"
            )
        } catch {
            print("❌ [DecisionMatrix] OpenAI call failed")
            print("   Error: \(error.localizedDescription)")
            throw error
        }

        // Build result
        let executionTime = Date().timeIntervalSince(startTime)

        // Create one result item per option
        let resultItems = response.options.map { option in
            var content: [String: Any] = [
                "option": option.option,
                "overallScore": option.overallScore,
                "criteriaScores": option.criteriaScores.map { score in
                    [
                        "criterion": score.criterion,
                        "score": score.score,
                        "reasoning": score.reasoning,
                        "evidence": score.evidence
                    ]
                },
                "pros": option.pros,
                "cons": option.cons,
                "risks": option.risks
            ]

            if let counterfactual = response.counterfactualAnalysis {
                content["counterfactualAnalysis"] = counterfactual
            }

            return AnalysisResult.AnalysisItem(id: nil, content: content)
        }

        let confidence: AnalysisResult.AnalysisMetadata.Confidence
        if context.dataPointCount >= 30 {
            confidence = .high
        } else if context.dataPointCount >= 10 {
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
            operation: "decision_matrix",
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
        var happinessPoints: [(date: String, value: Double)] = []
        var totalItems = 0

        // Get recommended token budget for this operation
        let budget = TokenBudgetManager.recommendedBudget(for: "decision_matrix")

        for input in inputs {
            if let items = input["items"] as? [[String: Any]] {
                totalItems += items.count

                // Use TokenBudgetManager to dynamically select entries that fit budget
                let (selectedItems, estimatedTokens) = TokenBudgetManager.selectEntries(
                    from: items,
                    targetTokenBudget: budget,
                    systemPromptTokens: 1200  // Reserve for system prompt + response
                )

                // Log what we're about to send
                TokenBudgetManager.logBudgetInfo(
                    operation: "DecisionMatrix",
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

                    // Extract happiness/wellbeing metrics
                    if let scoreComponents = item["scoreComponents"] as? [String: Any],
                       let magnitude = scoreComponents["magnitude"] as? Double {
                        let date = item["date"] as? String ?? "unknown"
                        happinessPoints.append((date: date, value: magnitude))
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
        if happinessPoints.isEmpty {
            analyticsSummary = "No wellbeing metrics available"
        } else {
            let avgHappiness = happinessPoints.map { $0.value }.reduce(0, +) / Double(happinessPoints.count)
            analyticsSummary = "Average wellbeing: \(String(format: "%.1f", avgHappiness * 100))/100 across \(happinessPoints.count) data points"
        }

        return Context(
            journalSummary: journalSummary,
            analyticsSummary: analyticsSummary,
            dataPointCount: journalTexts.count
        )
    }

    private func buildSystemPrompt(
        criteria: [String],
        options: [String],
        includeCounterfactuals: Bool
    ) -> String {
        return """
        You are a decision analysis expert helping someone make an important life decision.

        Your task is to create a **structured decision matrix** evaluating these options: \(options.joined(separator: ", "))

        Evaluate each option against these criteria: \(criteria.joined(separator: ", "))

        For each option:
        1. **Overall score**: Weighted average of all criteria (0-10 scale)
        2. **Criteria scores**: Score (0-10) for each criterion with reasoning and evidence
        3. **Pros**: Key advantages (3-5 bullet points)
        4. **Cons**: Key disadvantages (3-5 bullet points)
        5. **Risks**: Potential negative outcomes or uncertainties

        \(includeCounterfactuals ? """
        Additionally, provide a **counterfactual analysis**:
        - Look for similar past decisions in the journal
        - What was chosen? What was the outcome?
        - What might have happened if they'd chosen differently?
        - What lessons can be learned?
        """ : "")

        Guidelines:
        - Be objective and evidence-based
        - Quote specific journal entries with dates
        - Consider both short-term and long-term impacts
        - Acknowledge uncertainty where it exists
        - Don't be prescriptive - present the analysis neutrally
        """
    }

    private func buildJSONSchema(criteria: [String], options: [String]) -> [String: Any] {
        return [
            "name": "decision_matrix_response",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "options": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "option": ["type": "string"],
                                "overallScore": ["type": "number"],
                                "criteriaScores": [
                                    "type": "array",
                                    "items": [
                                        "type": "object",
                                        "properties": [
                                            "criterion": ["type": "string"],
                                            "score": ["type": "number"],
                                            "reasoning": ["type": "string"],
                                            "evidence": ["type": "string"]
                                        ],
                                        "required": ["criterion", "score", "reasoning", "evidence"],
                                        "additionalProperties": false
                                    ]
                                ],
                                "pros": [
                                    "type": "array",
                                    "items": ["type": "string"]
                                ],
                                "cons": [
                                    "type": "array",
                                    "items": ["type": "string"]
                                ],
                                "risks": [
                                    "type": "array",
                                    "items": ["type": "string"]
                                ]
                            ],
                            "required": ["option", "overallScore", "criteriaScores", "pros", "cons", "risks"],
                            "additionalProperties": false
                        ]
                    ],
                    "counterfactualAnalysis": ["type": "string"]
                ],
                "required": ["options"],
                "additionalProperties": false
            ]
        ]
    }
}

// MARK: - Response Models

private struct DecisionMatrixResponse: Codable {
    let options: [Option]
    let counterfactualAnalysis: String?

    struct Option: Codable {
        let option: String
        let overallScore: Double
        let criteriaScores: [CriterionScore]
        let pros: [String]
        let cons: [String]
        let risks: [String]
    }

    struct CriterionScore: Codable {
        let criterion: String
        let score: Double
        let reasoning: String
        let evidence: String
    }
}
