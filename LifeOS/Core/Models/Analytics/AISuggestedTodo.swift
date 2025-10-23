import Foundation

/// An AI-suggested action item based on journal analysis
struct AISuggestedTodo: Codable, Identifiable {
    /// Unique identifier
    let id: UUID

    /// The main title/description of the todo
    let title: String

    /// A concrete first step to get started
    let firstStep: String

    /// Why this action matters (rationale from AI)
    let whyItMatters: String

    /// Theme category (e.g., "health", "relationships", "work", "personal")
    let theme: String

    /// Estimated time to complete in minutes
    let estimatedMinutes: Int

    init(
        id: UUID = UUID(),
        title: String,
        firstStep: String,
        whyItMatters: String,
        theme: String,
        estimatedMinutes: Int
    ) {
        self.id = id
        self.title = title
        self.firstStep = firstStep
        self.whyItMatters = whyItMatters
        self.theme = theme
        self.estimatedMinutes = estimatedMinutes
    }

    /// Convert to the existing TODOItem model for integration with the journal
    func toTODOItem() -> TODOItem {
        return TODOItem(
            id: id,
            text: title,
            completed: false,
            createdAt: Date()
        )
    }

    /// User-friendly time estimate
    var timeEstimateDescription: String {
        if estimatedMinutes < 60 {
            return "\(estimatedMinutes) min"
        } else {
            let hours = estimatedMinutes / 60
            let mins = estimatedMinutes % 60
            if mins == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(mins) min"
            }
        }
    }

    /// Theme emoji for visual display
    var themeEmoji: String {
        switch theme.lowercased() {
        case "health": return "🏃"
        case "relationships", "social": return "👥"
        case "work", "career": return "💼"
        case "personal", "self": return "🧘"
        case "finance", "financial": return "💰"
        case "learning", "education": return "📚"
        case "creativity": return "🎨"
        case "home": return "🏠"
        default: return "✓"
        }
    }
}
