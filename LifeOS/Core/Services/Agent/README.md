# Agent System - Phase 3

This directory contains the ReAct Agent System implementation for LifeOS.

## Overview

The Agent System provides a conversational AI that can answer questions about your life using your journal data. It implements a ReAct (Reasoning + Acting) loop where the AI reasons about what information it needs and then acts by calling tools to retrieve that information.

## Architecture

### Core Components

1. **AgentKernel** - Main ReAct loop orchestrator
2. **ToolRegistry** - Manages and executes tools
3. **AgentMessage** - Message types for conversation history
4. **AgentResponse** - Response format with metadata

### Tools (5 total)

1. **SearchSemanticTool** - Semantic search through journal entries
2. **GetMonthSummaryTool** - Monthly AI summaries
3. **GetYearSummaryTool** - Yearly AI summaries  
4. **GetTimeSeriesTool** - Happiness/stress/energy time series
5. **GetCurrentStateSnapshotTool** - Current life state analysis

### Supporting Services

- **CurrentStateAnalyzer** - Analyzes recent entries to generate current state snapshot

## Usage Example

```swift
// 1. Create database and OpenAI services
let databaseService = DatabaseService()
let openAI = OpenAIService()

// 2. Create tool registry with all tools
let toolRegistry = ToolRegistry.createStandardRegistry(
    databaseService: databaseService,
    openAI: openAI
)

// 3. Create agent kernel
let agent = AgentKernel(
    openAI: openAI,
    toolRegistry: toolRegistry,
    maxIterations: 10,
    model: "gpt-4o"
)

// 4. Run agent with user question
let response = try await agent.runAgent(
    userMessage: "How have I been feeling this month?",
    conversationHistory: []
)

print(response.text)
print("Tools used:", response.toolsUsed)
print("Iterations:", response.metadata.iterations)
```

## Conversation Flow

```
User: "How have I been feeling this month?"
    ↓
AgentKernel starts ReAct loop
    ↓
Model decides to call tools:
  - get_month_summary(year: 2025, month: 10)
  - get_time_series(metric: "happiness", from: "2025-10-01", to: "2025-10-31")
    ↓
ToolRegistry executes tools
    ↓
Model receives tool results
    ↓
Model generates final response with insights
    ↓
User receives response
```

## Models

New models in `LifeOS/Core/Models/Analytics/`:
- **Trend** - Trend direction (up/down/stable)
- **MoodState** - Current mood with trends
- **AISuggestedTodo** - AI-suggested action items
- **CurrentState** - Current life state snapshot

## Dependencies

- Phase 1: All data models, database layer, vector search, OpenAI integration
- Phase 2: Analytics pipeline, summarization services
- OpenAIService with tool calling support (chatCompletionWithTools)

## Next Steps (Phase 4)

- Build UI for analytics dashboard
- Create AI chat interface
- Add current state dashboard view

