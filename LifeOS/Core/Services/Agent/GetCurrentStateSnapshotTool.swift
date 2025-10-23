import Foundation

/// Tool for analyzing current life state with themes, mood, stressors, and AI suggestions
class GetCurrentStateSnapshotTool: AgentTool {
    private let analyzer: CurrentStateAnalyzer

    let name = "get_current_state"
    let description = "Analyze current life state including themes, mood trends, stressors, protective factors, and get AI-suggested action items. Use this when the user asks 'how am I doing?' or wants actionable advice."

    let parametersSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "days": [
                "type": "integer",
                "description": "Number of recent days to analyze (default: 30, max: 90)",
                "default": 30
            ]
        ]
    ]

    init(analyzer: CurrentStateAnalyzer) {
        self.analyzer = analyzer
    }

    func execute(arguments: [String: Any]) async throws -> Any {
        // Extract arguments
        let days = (arguments["days"] as? Int) ?? 30
        let limitedDays = min(days, 90) // Cap at 90 days

        // Perform the analysis
        let currentState = try await analyzer.analyze(days: limitedDays)

        // Format for the agent
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return [
            "analyzedAt": formatter.string(from: currentState.analyzedAt),
            "daysAnalyzed": currentState.daysAnalyzed,
            "themes": currentState.themes,
            "mood": [
                "happiness": [
                    "value": round(currentState.mood.happiness * 10) / 10,
                    "trend": currentState.mood.happinessTrend.rawValue,
                    "description": currentState.mood.happinessTrend.description
                ],
                "stress": [
                    "value": round(currentState.mood.stress * 10) / 10,
                    "trend": currentState.mood.stressTrend.rawValue,
                    "description": currentState.mood.stressTrend.description
                ],
                "energy": [
                    "value": round(currentState.mood.energy * 10) / 10,
                    "trend": currentState.mood.energyTrend.rawValue,
                    "description": currentState.mood.energyTrend.description
                ],
                "summary": currentState.mood.summary
            ],
            "stressors": currentState.stressors,
            "protectiveFactors": currentState.protectiveFactors,
            "suggestedTodos": currentState.suggestedTodos.map { todo in
                [
                    "title": todo.title,
                    "firstStep": todo.firstStep,
                    "whyItMatters": todo.whyItMatters,
                    "theme": todo.theme,
                    "estimatedMinutes": todo.estimatedMinutes,
                    "timeEstimate": todo.timeEstimateDescription
                ]
            },
            "todosByTheme": currentState.todosByTheme.mapValues { todos in
                todos.map { todo in
                    [
                        "title": todo.title,
                        "firstStep": todo.firstStep,
                        "whyItMatters": todo.whyItMatters,
                        "estimatedMinutes": todo.estimatedMinutes
                    ]
                }
            }
        ]
    }
}
