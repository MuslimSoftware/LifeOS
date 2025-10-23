import Foundation

/// The final response from the agent after completing the ReAct loop
struct AgentResponse: Codable {
    /// The final text response to show the user
    let text: String

    /// Names of tools that were called during the interaction
    let toolsUsed: [String]

    /// Metadata about the agent execution
    let metadata: ResponseMetadata

    init(text: String, toolsUsed: [String], metadata: ResponseMetadata) {
        self.text = text
        self.toolsUsed = toolsUsed
        self.metadata = metadata
    }
}

/// Metadata about the agent's execution
struct ResponseMetadata: Codable {
    /// Number of ReAct loop iterations
    let iterations: Int

    /// Total time taken in seconds
    let durationSeconds: Double

    /// Model used for the response
    let model: String

    /// Estimated token usage
    let estimatedTokens: TokenUsage?

    /// Whether the loop hit the max iteration limit
    let hitMaxIterations: Bool

    init(
        iterations: Int,
        durationSeconds: Double,
        model: String,
        estimatedTokens: TokenUsage? = nil,
        hitMaxIterations: Bool = false
    ) {
        self.iterations = iterations
        self.durationSeconds = durationSeconds
        self.model = model
        self.estimatedTokens = estimatedTokens
        self.hitMaxIterations = hitMaxIterations
    }
}

/// Estimated token usage for the response
struct TokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    var estimatedCost: Double {
        // GPT-4o pricing (as of 2024)
        let inputCostPer1M = 2.50
        let outputCostPer1M = 10.00

        let inputCost = Double(promptTokens) / 1_000_000.0 * inputCostPer1M
        let outputCost = Double(completionTokens) / 1_000_000.0 * outputCostPer1M

        return inputCost + outputCost
    }
}
