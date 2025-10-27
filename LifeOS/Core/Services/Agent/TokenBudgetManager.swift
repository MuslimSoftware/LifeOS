import Foundation

/// Manages token budgets for AI analysis operations
/// Dynamically selects entries to fit within user's rate limits
class TokenBudgetManager {

    // MARK: - UserDefaults Key

    static let maxTokensKey = "ai.analysis.maxTokensPerRequest"
    static let defaultMaxTokens = 30000  // Conservative default (most orgs have 30K TPM minimum)

    // MARK: - User Settings

    /// Get user's configured max tokens per request
    static var userMaxTokens: Int {
        let stored = UserDefaults.standard.integer(forKey: maxTokensKey)
        return stored > 0 ? stored : defaultMaxTokens
    }

    // MARK: - Token Estimation

    /// Estimate tokens for text
    /// Rule of thumb: 1 token ≈ 4 characters (conservative estimate)
    static func estimateTokens(text: String) -> Int {
        return text.count / 4
    }

    /// Estimate tokens for a journal item
    static func estimateTokens(item: [String: Any]) -> Int {
        var tokens = 50  // Base overhead (metadata, JSON structure)

        if let text = item["text"] as? String {
            tokens += estimateTokens(text: text)
        }

        if let date = item["date"] as? String {
            tokens += estimateTokens(text: date)
        }

        return tokens
    }

    // MARK: - Entry Selection

    /// Select entries that fit within target token budget
    /// - Parameters:
    ///   - items: Array of items from retrieve tool (already ranked by relevance)
    ///   - targetTokenBudget: Maximum tokens to use
    ///   - systemPromptTokens: Reserved tokens for system prompt + response
    /// - Returns: Tuple of (selected items, estimated total tokens)
    static func selectEntries(
        from items: [[String: Any]],
        targetTokenBudget: Int,
        systemPromptTokens: Int = 2000  // Reserve for system prompt + expected response
    ) -> (selected: [[String: Any]], estimatedTokens: Int) {

        var selected: [[String: Any]] = []
        var totalTokens = systemPromptTokens  // Start with system prompt overhead

        for item in items {
            let itemTokens = estimateTokens(item: item)

            // Check if adding this item would exceed budget
            if totalTokens + itemTokens <= targetTokenBudget {
                selected.append(item)
                totalTokens += itemTokens
            } else {
                // Budget exhausted - stop adding items
                break
            }
        }

        return (selected, totalTokens)
    }

    // MARK: - Budget Recommendations

    /// Get recommended token budget for different analysis operations
    /// - Parameters:
    ///   - operation: The analysis operation type
    ///   - userLimit: User's max tokens (defaults to user setting)
    /// - Returns: Recommended budget for this operation
    static func recommendedBudget(
        for operation: String,
        userLimit: Int? = nil
    ) -> Int {
        let limit = userLimit ?? userMaxTokens

        // Different operations have different token requirements
        switch operation {
        case "lifelong_patterns":
            // Needs most data - use 90% of budget (reserve 10% for safety)
            return Int(Double(limit) * 0.9)

        case "decision_matrix":
            // Needs recent detailed context - use 80% of budget
            return Int(Double(limit) * 0.8)

        case "action_synthesis":
            // Only needs recent entries - use 40% of budget
            return Int(Double(limit) * 0.4)

        default:
            // Unknown operation - be conservative
            return Int(Double(limit) * 0.7)
        }
    }

    // MARK: - Logging Helpers

    /// Log token budget information for debugging
    static func logBudgetInfo(
        operation: String,
        totalItems: Int,
        selectedItems: Int,
        estimatedTokens: Int,
        budget: Int
    ) {
        print("🧠 [\(operation)] Token Budget:")
        print("   Selected: \(selectedItems)/\(totalItems) entries")
        print("   Est. tokens: \(estimatedTokens)/\(budget)")
        print("   Utilization: \(Int((Double(estimatedTokens) / Double(budget)) * 100))%")
    }
}

// MARK: - Helper Extensions

private extension Int {
    /// Return self if non-zero, otherwise return the default value
    func ifZero(_ defaultValue: Int) -> Int {
        return self > 0 ? self : defaultValue
    }
}
