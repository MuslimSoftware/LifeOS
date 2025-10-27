import Foundation

/// Universal analysis tool
/// Routes to specialized analyzers for different operations
class AnalyzeTool: AgentTool {
    let name = "analyze"
    let description = "Run analysis or transforms on retrieved data using LLM-powered insights. Use after calling retrieve to generate actionable insights, identify patterns, or make decisions."

    private let openAI: OpenAIService

    // Lazy-initialized analyzers
    private lazy var lifelongPatternsAnalyzer = LifelongPatternsAnalyzer(openAI: openAI)
    private lazy var decisionMatrixAnalyzer = DecisionMatrixAnalyzer(openAI: openAI)
    private lazy var actionSynthesisAnalyzer = ActionSynthesisAnalyzer(openAI: openAI)

    let parametersSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "op": [
                "type": "string",
                "enum": [
                    "lifelong_patterns",
                    "decision_matrix",
                    "action_synthesis"
                ],
                "description": "Operation to perform"
            ],
            "inputs": [
                "type": "array",
                "description": "Array of result IDs from retrieve calls (e.g., [\"retrieve_1\"]) or full result objects. When retrieve returns a resultId, pass that ID here to analyze the full cached data.",
                "items": [
                    "anyOf": [
                        ["type": "string"],
                        ["type": "object"]
                    ]
                ]
            ],
            "config": [
                "type": "object",
                "description": "Operation-specific configuration",
                "properties": [
                    "maxItems": [
                        "type": "integer",
                        "description": "Maximum items to return (for action_synthesis)"
                    ],
                    "minOccurrences": [
                        "type": "integer",
                        "description": "Minimum pattern occurrences (for lifelong_patterns)"
                    ],
                    "minSpanMonths": [
                        "type": "integer",
                        "description": "Minimum time span in months (for lifelong_patterns)"
                    ],
                    "balance": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Life areas to balance (for action_synthesis)"
                    ],
                    "criteria": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Decision criteria (for decision_matrix)"
                    ],
                    "options": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Options to evaluate (for decision_matrix)"
                    ],
                    "includeFirstStep": [
                        "type": "boolean",
                        "description": "Include first step in actions (for action_synthesis)"
                    ],
                    "includeCounterfactuals": [
                        "type": "boolean",
                        "description": "Include what-if analysis (for decision_matrix)"
                    ],
                    "requireRecurring": [
                        "type": "boolean",
                        "description": "Only detect recurring patterns (for lifelong_patterns)"
                    ]
                ]
            ]
        ],
        "required": ["op", "inputs"]
    ]

    init(openAI: OpenAIService) {
        self.openAI = openAI
    }

    func execute(arguments: [String: Any]) async throws -> Any {
        // Extract operation
        guard let op = arguments["op"] as? String else {
            throw AnalyzeToolError.missingOperation
        }

        // Extract and resolve inputs
        // Inputs can be:
        // 1. Array of strings (result IDs) - resolve from cache
        // 2. Array of dictionaries (direct data) - use as-is
        let inputs: [[String: Any]]
        if let inputStrings = arguments["inputs"] as? [String] {
            // Resolve result IDs from cache
            print("🧠 [Analyze] Resolving \(inputStrings.count) cached result(s): \(inputStrings.joined(separator: ", "))")

            inputs = try inputStrings.compactMap { resultId in
                guard let cachedResult = ResultCacheService.shared.get(id: resultId) else {
                    throw AnalyzeToolError.resultNotFound(resultId)
                }

                guard let resultDict = cachedResult as? [String: Any] else {
                    throw AnalyzeToolError.invalidCachedResult(resultId)
                }

                return resultDict
            }

            print("🧠 [Analyze] Resolved to \(inputs.count) full result(s)")
        } else if let inputDicts = arguments["inputs"] as? [[String: Any]] {
            // Direct data (for backward compatibility or testing)
            inputs = inputDicts
        } else {
            throw AnalyzeToolError.invalidInputs
        }

        // Extract config (optional)
        let config = arguments["config"] as? [String: Any] ?? [:]

        print("🧠 [Analyze] Operation: \(op), Processing \(inputs.count) input(s)")

        // Route to appropriate analyzer
        let result: AnalysisResult
        switch op {
        case "lifelong_patterns":
            result = try await lifelongPatternsAnalyzer.analyze(inputs: inputs, config: config)

        case "decision_matrix":
            result = try await decisionMatrixAnalyzer.analyze(inputs: inputs, config: config)

        case "action_synthesis":
            result = try await actionSynthesisAnalyzer.analyze(inputs: inputs, config: config)

        default:
            throw AnalyzeToolError.unknownOperation(op)
        }

        print("🧠 [Analyze] Generated \(result.results.count) results (confidence: \(result.metadata.confidence))")

        return result.toJSON()
    }
}

// MARK: - Errors

enum AnalyzeToolError: Error, LocalizedError {
    case missingOperation
    case invalidInputs
    case unknownOperation(String)
    case analysisExecutionFailed(String)
    case resultNotFound(String)
    case invalidCachedResult(String)

    var errorDescription: String? {
        switch self {
        case .missingOperation:
            return "Missing required 'op' parameter"
        case .invalidInputs:
            return "Invalid 'inputs' parameter - must be an array of result IDs (strings) or retrieve result objects (dictionaries)"
        case .unknownOperation(let op):
            return "Unknown operation: '\(op)'. Available: lifelong_patterns, decision_matrix, action_synthesis"
        case .analysisExecutionFailed(let message):
            return "Analysis execution failed: \(message)"
        case .resultNotFound(let resultId):
            return "Cached result not found: '\(resultId)'. Make sure you pass the resultId from a previous retrieve call."
        case .invalidCachedResult(let resultId):
            return "Cached result '\(resultId)' has invalid format"
        }
    }
}
