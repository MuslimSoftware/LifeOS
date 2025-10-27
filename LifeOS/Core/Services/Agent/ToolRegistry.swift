import Foundation

/// Central registry for managing and executing agent tools
class ToolRegistry {
    private var tools: [String: AgentTool] = [:]

    /// Register a tool with the registry
    /// - Parameter tool: The tool to register
    func registerTool(_ tool: AgentTool) {
        tools[tool.name] = tool
    }

    /// Get all registered tool names
    var registeredToolNames: [String] {
        Array(tools.keys).sorted()
    }

    /// Get OpenAI function definitions for all registered tools
    /// This format is used for the OpenAI function calling API
    /// - Returns: Array of function definitions
    func getToolSchemas() -> [[String: Any]] {
        return tools.values.map { $0.toOpenAIFunction() }
    }

    /// Execute a tool by name with the given arguments
    /// - Parameters:
    ///   - name: The name of the tool to execute
    ///   - arguments: Dictionary of arguments for the tool
    /// - Returns: The result of the tool execution
    /// - Throws: ToolRegistryError if the tool is not found or execution fails
    func executeTool(name: String, arguments: [String: Any]) async throws -> Any {
        guard let tool = tools[name] else {
            throw ToolRegistryError.toolNotFound(name)
        }

        do {
            let result = try await tool.execute(arguments: arguments)
            return result
        } catch {
            throw ToolRegistryError.executionFailed(toolName: name, error: error)
        }
    }

    /// Get a tool by name
    /// - Parameter name: The tool name
    /// - Returns: The tool if found, nil otherwise
    func getTool(name: String) -> AgentTool? {
        return tools[name]
    }

    /// Remove all registered tools
    func clearAll() {
        tools.removeAll()
    }

    /// Get the count of registered tools
    var count: Int {
        tools.count
    }
}

// MARK: - Errors

enum ToolRegistryError: Error, LocalizedError {
    case toolNotFound(String)
    case executionFailed(toolName: String, error: Error)

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: '\(name)'. Available tools: \(name)"
        case .executionFailed(let toolName, let error):
            return "Tool '\(toolName)' execution failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Convenience Initializer

extension ToolRegistry {
    /// Create a fully configured tool registry with minimal composable tools
    /// - Parameters:
    ///   - databaseService: The database service for repositories
    ///   - openAI: The OpenAI service
    /// - Returns: A configured ToolRegistry
    static func createStandardRegistry(
        databaseService: DatabaseService,
        openAI: OpenAIService
    ) -> ToolRegistry {
        let registry = ToolRegistry()

        // Create repositories
        let chunkRepository = ChunkRepository(dbService: databaseService)
        let entryAnalyticsRepository = EntryAnalyticsRepository(dbService: databaseService)
        let monthSummaryRepository = MonthSummaryRepository(dbService: databaseService)
        let yearSummaryRepository = YearSummaryRepository(dbService: databaseService)
        let memoryRepository = AgentMemoryRepository(dbService: databaseService)

        // Create services
        let bm25 = BM25Service(dbService: databaseService)
        let calculator = HappinessIndexCalculator()

        // Register retrieve tool (replaces 5 old tools, now with memory support)
        registry.registerTool(RetrieveTool(
            chunkRepository: chunkRepository,
            analyticsRepository: entryAnalyticsRepository,
            monthSummaryRepository: monthSummaryRepository,
            yearSummaryRepository: yearSummaryRepository,
            memoryRepository: memoryRepository,
            openAI: openAI,
            bm25: bm25
        ))

        // Register analyze tool (Phase 2)
        registry.registerTool(AnalyzeTool(openAI: openAI))

        // Register memory_write tool (Phase 4)
        registry.registerTool(MemoryWriteTool(repository: memoryRepository))

        // Register context_bundle tool (Phase 4)
        registry.registerTool(ContextBundleTool(
            analyticsRepository: entryAnalyticsRepository,
            monthSummaryRepository: monthSummaryRepository,
            memoryRepository: memoryRepository,
            calculator: calculator
        ))

        return registry
    }
}
