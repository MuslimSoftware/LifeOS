import Foundation

/// Service for analyzing current life state based on recent journal entries
class CurrentStateAnalyzer {
    private let repository: EntryAnalyticsRepository
    private let calculator: HappinessIndexCalculator
    private let openAI: OpenAIService

    init(
        repository: EntryAnalyticsRepository,
        calculator: HappinessIndexCalculator,
        openAI: OpenAIService
    ) {
        self.repository = repository
        self.calculator = calculator
        self.openAI = openAI
    }

    /// Analyze the current state based on recent journal entries
    /// - Parameter days: Number of recent days to analyze (default: 30)
    /// - Returns: A CurrentState snapshot with themes, mood, and suggestions
    func analyze(days: Int = 30) async throws -> CurrentState {
        let calendar = Calendar.current
        let toDate = Date()
        guard let fromDate = calendar.date(byAdding: .day, value: -days, to: toDate) else {
            throw AnalysisError.invalidDateRange
        }

        // Load recent entries
        let entries = try repository.getAnalytics(from: fromDate, to: toDate)

        guard !entries.isEmpty else {
            throw AnalysisError.noDataAvailable
        }

        // Compute mood metrics
        let mood = try computeMoodState(entries: entries, days: days)

        // Use AI to extract themes, stressors, protective factors, and suggested todos
        let aiAnalysis = try await extractAIInsights(entries: entries, mood: mood)

        return CurrentState(
            themes: aiAnalysis.themes,
            mood: mood,
            stressors: aiAnalysis.stressors,
            protectiveFactors: aiAnalysis.protectiveFactors,
            suggestedTodos: aiAnalysis.suggestedTodos,
            analyzedAt: Date(),
            daysAnalyzed: days
        )
    }

    // MARK: - Private Methods

    private func computeMoodState(entries: [EntryAnalytics], days: Int) throws -> MoodState {
        let calendar = Calendar.current

        // Split entries into recent (last 7 days) and previous (8-14 days ago)
        let now = Date()
        guard let recentStart = calendar.date(byAdding: .day, value: -7, to: now),
              let previousStart = calendar.date(byAdding: .day, value: -14, to: now) else {
            throw AnalysisError.invalidDateRange
        }

        let recentEntries = entries.filter { $0.date >= recentStart }
        let previousEntries = entries.filter { $0.date >= previousStart && $0.date < recentStart }

        // Calculate current metrics (recent 7 days)
        let recentHappiness = recentEntries.map { $0.happinessScore }
        let currentHappiness = recentHappiness.isEmpty ? 50.0 : recentHappiness.reduce(0, +) / Double(recentHappiness.count)

        let recentStress = recentEntries.compactMap { entry in
            calculator.computeStressScore(
                anxiety: entry.emotions.anxiety,
                arousal: entry.arousal,
                negativeEventDensity: Double(entry.events.filter { $0.sentiment < -0.3 }.count)
            )
        }
        let currentStress = recentStress.isEmpty ? 50.0 : recentStress.reduce(0, +) / Double(recentStress.count)

        let recentEnergy = recentEntries.compactMap { entry in
            calculator.computeEnergyScore(
                arousal: entry.arousal,
                valence: entry.valence,
                joy: entry.emotions.joy
            )
        }
        let currentEnergy = recentEnergy.isEmpty ? 50.0 : recentEnergy.reduce(0, +) / Double(recentEnergy.count)

        // Calculate previous metrics (8-14 days ago) for trend comparison
        let previousHappiness = previousEntries.map { $0.happinessScore }
        let prevHappiness = previousHappiness.isEmpty ? currentHappiness : previousHappiness.reduce(0, +) / Double(previousHappiness.count)

        let previousStress = previousEntries.compactMap { entry in
            calculator.computeStressScore(
                anxiety: entry.emotions.anxiety,
                arousal: entry.arousal,
                negativeEventDensity: Double(entry.events.filter { $0.sentiment < -0.3 }.count)
            )
        }
        let prevStress = previousStress.isEmpty ? currentStress : previousStress.reduce(0, +) / Double(previousStress.count)

        let previousEnergy = previousEntries.compactMap { entry in
            calculator.computeEnergyScore(
                arousal: entry.arousal,
                valence: entry.valence,
                joy: entry.emotions.joy
            )
        }
        let prevEnergy = previousEnergy.isEmpty ? currentEnergy : previousEnergy.reduce(0, +) / Double(previousEnergy.count)

        // Determine trends
        let happinessTrend = Trend(current: currentHappiness, previous: prevHappiness, threshold: 5.0)
        let stressTrend = Trend(current: currentStress, previous: prevStress, threshold: 5.0)
        let energyTrend = Trend(current: currentEnergy, previous: prevEnergy, threshold: 5.0)

        return MoodState(
            happiness: currentHappiness,
            stress: currentStress,
            energy: currentEnergy,
            happinessTrend: happinessTrend,
            stressTrend: stressTrend,
            energyTrend: energyTrend
        )
    }

    private func extractAIInsights(entries: [EntryAnalytics], mood: MoodState) async throws -> AIAnalysis {
        // Prepare data for AI analysis
        let summary = prepareSummaryForAI(entries: entries, mood: mood)

        // Create the schema for structured output
        let schema = CurrentStateSchema.schema

        // Call OpenAI with structured outputs
        let response: CurrentStateResponse = try await openAI.chatCompletion(
            messages: [
                ["role": "system", "content": CurrentStateSchema.systemPrompt],
                ["role": "user", "content": summary]
            ],
            schema: schema,
            model: "gpt-4o"
        )

        // Convert to AISuggestedTodo objects
        let suggestedTodos = response.suggestedTodos.map { todoData in
            AISuggestedTodo(
                title: todoData.title,
                firstStep: todoData.firstStep,
                whyItMatters: todoData.whyItMatters,
                theme: todoData.theme,
                estimatedMinutes: todoData.estimatedMinutes
            )
        }

        return AIAnalysis(
            themes: response.themes,
            stressors: response.stressors,
            protectiveFactors: response.protectiveFactors,
            suggestedTodos: suggestedTodos
        )
    }

    private func prepareSummaryForAI(entries: [EntryAnalytics], mood: MoodState) -> String {
        var summary = """
        Analyze the following journal analytics data from the last \(entries.count) entries to understand the user's current life state.

        CURRENT MOOD METRICS:
        - Happiness: \(String(format: "%.1f", mood.happiness))/100 (\(mood.happinessTrend.description))
        - Stress: \(String(format: "%.1f", mood.stress))/100 (\(mood.stressTrend.description))
        - Energy: \(String(format: "%.1f", mood.energy))/100 (\(mood.energyTrend.description))

        RECENT ENTRIES SUMMARY:
        """

        // Add top emotions across all entries
        let allEmotions = entries.map { $0.emotions }
        let avgJoy = allEmotions.map { $0.joy }.reduce(0, +) / Double(allEmotions.count)
        let avgSadness = allEmotions.map { $0.sadness }.reduce(0, +) / Double(allEmotions.count)
        let avgAnxiety = allEmotions.map { $0.anxiety }.reduce(0, +) / Double(allEmotions.count)
        let avgAnger = allEmotions.map { $0.anger }.reduce(0, +) / Double(allEmotions.count)
        let avgGratitude = allEmotions.map { $0.gratitude }.reduce(0, +) / Double(allEmotions.count)

        summary += """

        Average Emotions:
        - Joy: \(String(format: "%.2f", avgJoy))
        - Sadness: \(String(format: "%.2f", avgSadness))
        - Anxiety: \(String(format: "%.2f", avgAnxiety))
        - Anger: \(String(format: "%.2f", avgAnger))
        - Gratitude: \(String(format: "%.2f", avgGratitude))

        KEY EVENTS:
        """

        // Add all detected events
        let allEvents = entries.flatMap { $0.events }
        let sortedEvents = allEvents.sorted { abs($0.sentiment) > abs($1.sentiment) }.prefix(15)

        for event in sortedEvents {
            let sentiment = event.sentiment > 0 ? "positive" : event.sentiment < 0 ? "negative" : "neutral"
            summary += "\n- \(event.title) (\(sentiment), \(String(format: "%.2f", event.sentiment)))"
            if let desc = event.description {
                summary += ": \(desc)"
            }
        }

        summary += """


        Based on this data, identify:
        1. Top 3-5 recurring themes in their life right now
        2. Active stressors or challenges (3-5 items)
        3. Protective factors or things going well (3-5 items)
        4. 5-10 actionable suggestions (todos) that would help them based on the patterns you see
        """

        return summary
    }
}

// MARK: - Supporting Types

private struct AIAnalysis {
    let themes: [String]
    let stressors: [String]
    let protectiveFactors: [String]
    let suggestedTodos: [AISuggestedTodo]
}

private struct CurrentStateResponse: Codable {
    let themes: [String]
    let stressors: [String]
    let protectiveFactors: [String]
    let suggestedTodos: [TodoData]

    struct TodoData: Codable {
        let title: String
        let firstStep: String
        let whyItMatters: String
        let theme: String
        let estimatedMinutes: Int
    }
}

private struct CurrentStateSchema {
    static let systemPrompt = """
    You are an empathetic AI analyst helping users understand their current life state based on journal analytics.

    Your role is to:
    1. Identify recurring themes and patterns
    2. Recognize both challenges (stressors) and strengths (protective factors)
    3. Suggest practical, actionable steps that are grounded in the data
    4. Be warm, supportive, and non-judgmental
    5. Focus on specific, concrete actions rather than vague advice

    When suggesting todos:
    - Make them specific and actionable (not "exercise more" but "go for a 20-minute walk after lunch")
    - Include realistic time estimates
    - Explain why it matters based on the data you see
    - Group by theme (health, relationships, work, personal, finance, learning, creativity, home)
    - Prioritize high-impact, low-effort actions
    """

    static let schema: [String: Any] = [
        "name": "current_state_analysis",
        "strict": true,
        "schema": [
            "type": "object",
            "properties": [
                "themes": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Top 3-5 themes in recent journal entries (e.g., 'Career growth', 'Health & fitness')"
                ],
                "stressors": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Active stressors/challenges (3-5 items, specific)"
                ],
                "protectiveFactors": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Things going well/protective factors (3-5 items, specific)"
                ],
                "suggestedTodos": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string", "description": "Concise todo title"],
                            "firstStep": ["type": "string", "description": "Concrete first step"],
                            "whyItMatters": ["type": "string", "description": "Why this helps based on the data"],
                            "theme": ["type": "string", "description": "Theme: health, relationships, work, personal, finance, learning, creativity, or home"],
                            "estimatedMinutes": ["type": "integer", "description": "Estimated minutes to complete"]
                        ],
                        "required": ["title", "firstStep", "whyItMatters", "theme", "estimatedMinutes"],
                        "additionalProperties": false
                    ],
                    "description": "5-10 AI-suggested action items"
                ]
            ],
            "required": ["themes", "stressors", "protectiveFactors", "suggestedTodos"],
            "additionalProperties": false
        ]
    ]
}

enum AnalysisError: Error, LocalizedError {
    case invalidDateRange
    case noDataAvailable
    case analysisFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return "Invalid date range for analysis"
        case .noDataAvailable:
            return "No journal entries found in the specified time period"
        case .analysisFailure(let message):
            return "Analysis failed: \(message)"
        }
    }
}
