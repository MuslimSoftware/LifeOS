import Foundation

/// Represents the current state of the user's life based on recent journal entries
struct CurrentState: Codable {
    /// Top 3-5 themes appearing in recent journal entries
    let themes: [String]

    /// Current mood metrics with trends
    let mood: MoodState

    /// Active stressors or challenges (3-5 items)
    let stressors: [String]

    /// Protective factors or things going well (3-5 items)
    let protectiveFactors: [String]

    /// AI-suggested action items (5-10 items)
    let suggestedTodos: [AISuggestedTodo]

    /// The date this analysis was performed
    let analyzedAt: Date

    /// Number of days of journal entries analyzed
    let daysAnalyzed: Int

    init(
        themes: [String],
        mood: MoodState,
        stressors: [String],
        protectiveFactors: [String],
        suggestedTodos: [AISuggestedTodo],
        analyzedAt: Date = Date(),
        daysAnalyzed: Int
    ) {
        self.themes = themes
        self.mood = mood
        self.stressors = stressors
        self.protectiveFactors = protectiveFactors
        self.suggestedTodos = suggestedTodos
        self.analyzedAt = analyzedAt
        self.daysAnalyzed = daysAnalyzed
    }

    /// Group suggested todos by theme
    var todosByTheme: [String: [AISuggestedTodo]] {
        Dictionary(grouping: suggestedTodos, by: { $0.theme })
    }

    /// Summary description of current state
    var summary: String {
        var parts: [String] = []

        // Mood summary
        parts.append(mood.summary)

        // Top themes
        if !themes.isEmpty {
            parts.append("Main themes: \(themes.prefix(3).joined(separator: ", "))")
        }

        // Stressor count
        if !stressors.isEmpty {
            parts.append("\(stressors.count) active stressor\(stressors.count == 1 ? "" : "s")")
        }

        // Protective factors
        if !protectiveFactors.isEmpty {
            parts.append("\(protectiveFactors.count) protective factor\(protectiveFactors.count == 1 ? "" : "s")")
        }

        return parts.joined(separator: ". ")
    }
}
