# Journal Analytics & AI Agent System - Implementation Tracker

## Project Overview
Building a pure Swift journal analytics system with AI agent capabilities for LifeOS. The system will analyze journal entries to compute quantified happiness metrics, generate insights, suggest todos, and provide an AI chat interface with full context about the user's life.

**Architecture**: 100% Swift, no Python backend. Local SQLite + vector storage, OpenAI API for LLM/embeddings.

---

## 🚀 Quick Start (For New Chat Sessions)

### Current Status
**Phase 1: COMPLETE ✅** - All core infrastructure built (models, database, vector search, OpenAI integration)

**Phase 2: COMPLETE ✅** - Full analytics pipeline (chunking, analysis, summarization)

**Next Up: Phase 3** - ReAct Agent System

### To Continue Implementation
1. **Review Phase 3 checklist below** (starts at line ~274)
2. **Start with**: Agent tools and tool registry
3. **Follow the order**: Tools → Tool Registry → Agent Kernel → Current State Analyzer
4. **All files go in**: `LifeOS/Core/Services/Agent/`

### Files Created So Far

**Phase 1:**
- 9 analytics data models in `LifeOS/Core/Models/Analytics/`
- DatabaseService with full schema in `LifeOS/Core/Services/Database/`
- 2 repository classes (ChunkRepository, EntryAnalyticsRepository)
- VectorSearchService with Accelerate framework
- Extended OpenAIService with embeddings + structured outputs + tool calling

**Phase 2:**
- `IngestionService.swift` - Text chunking with smart paragraph splitting
- `ChunkAnalytics.swift` + `ChunkAnalyticsSchema.swift` - Analytics extraction models
- `EntryAnalyzer.swift` - Chunk and entry-level analysis with aggregation
- `HappinessIndexCalculator.swift` - Happiness formula + statistical aggregates
- `SummarizationService.swift` - Monthly/yearly narrative generation
- `AnalyticsPipelineService.swift` - Full pipeline orchestration
- `MonthSummaryRepository.swift` + `YearSummaryRepository.swift` - Summary storage

### Key Decisions Made
- Using GRDB for SQLite (added to project)
- Text-embedding-3-large for embeddings (3072 dimensions)
- Happiness formula defined (see Phase 2.3)
- Structured outputs for all LLM extraction
- ReAct pattern for agent (Phase 3)

---

## Current Codebase Reference

### Existing Models
- `LifeOS/Core/Models/HumanEntry.swift` - Journal entry model
- `LifeOS/Core/Models/TODOItem.swift` - TODO item model
- `LifeOS/Core/Models/AppSettings.swift` - App settings
- `LifeOS/Core/Models/Theme.swift` - UI theme

### Existing Services
- `LifeOS/Core/Services/FileManagerService.swift` - File I/O, entry loading, TODO management, encryption integration
- `LifeOS/Core/Services/OpenAIService.swift` - ✅ **EXTENDED** with embeddings, structured outputs, tool calling
- `LifeOS/Core/Services/EncryptionService.swift` - AES-GCM encryption/decryption
- `LifeOS/Core/Services/KeychainService.swift` - Secure key storage
- `LifeOS/Core/Services/PDFExportService.swift` - PDF export

### New Analytics Services (Phase 1 Complete ✅)
- `LifeOS/Core/Services/Database/DatabaseService.swift` - SQLite + GRDB, migrations
- `LifeOS/Core/Services/Database/ChunkRepository.swift` - CRUD for journal chunks
- `LifeOS/Core/Services/Database/EntryAnalyticsRepository.swift` - CRUD for analytics
- `LifeOS/Core/Services/Analytics/VectorSearchService.swift` - Semantic search with Accelerate

### New Analytics Services (Phase 2 Complete ✅)

**Core Pipeline Services** (`LifeOS/Core/Services/Analytics/`):

- **`IngestionService.swift`** - Text chunking service
  - Splits journal entries into 700-1000 token chunks
  - Smart paragraph-aware splitting (doesn't break mid-sentence)
  - Token estimation using 1 token ≈ 4 chars heuristic
  - Tracks character positions for provenance
  - Main method: `chunkEntry(entry: HumanEntry, content: String) -> [JournalChunk]`

- **`ChunkAnalytics.swift`** - Temporary per-chunk analysis model
  - Stores emotions (joy, sadness, anger, anxiety, gratitude)
  - Happiness, valence, arousal scores
  - Detected events with sentiment
  - Gets aggregated into EntryAnalytics

- **`ChunkAnalyticsSchema.swift`** - JSON Schema for structured outputs
  - Defines extraction format for OpenAI API
  - Comprehensive system prompt for emotional intelligence analysis
  - Ensures consistent output format across all chunk analyses

- **`EntryAnalyzer.swift`** - Core analysis engine
  - `analyzeChunk()` - Calls OpenAI with structured outputs to extract emotions/events
  - `analyzeEntry()` - Analyzes all chunks and aggregates results
  - Uses trimmed mean for robust aggregation (removes outliers)
  - Merges and deduplicates detected events across chunks
  - Saves final EntryAnalytics to database

- **`HappinessIndexCalculator.swift`** - Happiness metrics & statistics
  - Implements happiness formula: `h = 50 + 30*valence + 10*gratitude - 12*anxiety - 10*sadness - 8*anger`
  - `computeMonthlyAggregates()` - Robust mean with confidence intervals
  - `computeTimeSeriesDataPoints()` - Generate time series for graphing
  - Uses IQR method to filter outliers
  - Bonus: `computeStressScore()` and `computeEnergyScore()` methods

- **`SummarizationService.swift`** - Hierarchical summarization
  - `summarizeMonth()` - Generates monthly summaries with narrative + positive/negative drivers
  - `summarizeYear()` - Generates yearly summaries from monthly data
  - Uses OpenAI structured outputs for consistent formatting
  - Extracts top events ranked by sentiment and salience
  - Computes happiness statistics with confidence intervals

- **`AnalyticsPipelineService.swift`** - Pipeline orchestrator
  - `processEntry()` - Full pipeline for single entry (chunk → embed → analyze → save)
  - `processAllEntries()` - Bulk processing with progress callbacks
  - `updateSummaries()` - Regenerate all month/year summaries
  - `processNewEntry()` - Optimized incremental processing for new entries
  - Error handling, retry logic, and rate limiting

**Repository Services** (`LifeOS/Core/Services/Database/`):

- **`MonthSummaryRepository.swift`** - CRUD for MonthSummary records
  - Save/query monthly summaries by year and month
  - JSON serialization for events and source spans
  - Stores drivers (positive/negative) and happiness stats

- **`YearSummaryRepository.swift`** - CRUD for YearSummary records
  - Save/query yearly summaries
  - JSON serialization for top events and source spans
  - Annual happiness trends and narratives

### New Analytics Models (Phase 1 Complete ✅)
- `LifeOS/Core/Models/Analytics/SourceSpan.swift` - Provenance tracking
- `LifeOS/Core/Models/Analytics/JournalChunk.swift` - Text chunk with embedding
- `LifeOS/Core/Models/Analytics/EmotionScores.swift` - Emotion metrics
- `LifeOS/Core/Models/Analytics/DetectedEvent.swift` - Event extraction
- `LifeOS/Core/Models/Analytics/EntryAnalytics.swift` - Per-entry analytics
- `LifeOS/Core/Models/Analytics/MonthSummary.swift` - Monthly aggregates
- `LifeOS/Core/Models/Analytics/YearSummary.swift` - Yearly aggregates
- `LifeOS/Core/Models/Analytics/TimeSeriesDataPoint.swift` - Time series data
- `LifeOS/Core/Models/Analytics/LifeEvent.swift` - Life events

### Existing Features
- `LifeOS/Features/Journal/JournalPageView.swift` - Main journal interface
- `LifeOS/Features/Editor/` - Entry editor
- `LifeOS/Features/EntryList/` - Entry browsing
- `LifeOS/Features/Calendar/` - Calendar & TODO views

---

## Implementation Phases

## Phase 1: Core Infrastructure ✅

### 1.1 Data Models
**Location**: `LifeOS/Core/Models/Analytics/`

- [x] `SourceSpan.swift` ✅
  - Properties: `entryId`, `startChar`, `endChar`
  - For provenance tracking

- [x] `JournalChunk.swift` ✅
  - Properties: `id`, `entryId`, `text`, `embedding`, `startChar`, `endChar`, `date`, `tokenCount`
  - Codable for serialization

- [x] `EmotionScores.swift` ✅
  - Properties: `joy`, `sadness`, `anger`, `anxiety`, `gratitude`
  - All normalized to [0, 1] range

- [x] `DetectedEvent.swift` ✅
  - Properties: `id`, `title`, `date`, `description`, `sentiment`

- [x] `EntryAnalytics.swift` ✅
  - Properties: `entryId`, `date`, `happinessScore`, `valence`, `arousal`, `emotions`, `events`, `confidence`
  - Complete analytics for a single journal entry

- [x] `MonthSummary.swift` ✅
  - Properties: `year`, `month`, `summaryText`, `happinessAvg`, `happinessCI`, `driversPositive`, `driversNegative`, `topEvents`, `sourceSpans`
  - Custom Codable for tuple serialization

- [x] `YearSummary.swift` ✅
  - Properties: `year`, `summaryText`, `happinessAvg`, `happinessCI`, `topEvents`, `sourceSpans`
  - Custom Codable for tuple serialization

- [x] `TimeSeriesDataPoint.swift` ✅
  - Properties: `date`, `metric` (happiness/stress/energy), `value`, `confidence`
  - Enum for metric types

- [x] `LifeEvent.swift` ✅
  - Properties: `id`, `title`, `startDate`, `endDate`, `description`, `categories`, `salience`, `sentiment`, `sourceSpans`

### 1.2 Database Layer
**Location**: `LifeOS/Core/Services/Database/`

- [x] Add GRDB Swift Package dependency ✅
  - Added to Xcode project (manual step in Xcode)

- [x] `DatabaseService.swift` ✅
  - SQLite connection management with DatabaseQueue
  - Complete schema migrations (v1_initial_schema)
  - Tables: chunks, entry_analytics, month_summaries, year_summaries, time_series, life_events
  - All indexes created for performance
  - Clear data method for reprocessing

- [x] `ChunkRepository.swift` ✅
  - CRUD operations for JournalChunk
  - Batch save support
  - Float array ↔ BLOB conversion
  - Query by entry ID, date range

- [x] `EntryAnalyticsRepository.swift` ✅
  - CRUD operations for EntryAnalytics
  - JSON serialization for emotions and events
  - Query by entry ID, date range

### 1.3 Vector Search Engine & OpenAI Integration
**Location**: `LifeOS/Core/Services/Analytics/`

- [x] `VectorSearchService.swift` ✅
  - Semantic search with cosine similarity using Accelerate/vDSP
  - Hybrid search (semantic + keyword)
  - Date range filtering
  - Min similarity threshold
  - Optimized vector math with Accelerate framework

**Location**: `LifeOS/Core/Services/`

- [x] Extended `OpenAIService.swift` ✅
  - `generateEmbedding(for:)` - Single text embedding
  - `generateEmbeddings(for:)` - Batch embeddings
  - `chatCompletion<T>(messages:schema:model:)` - Structured outputs
  - `chatCompletionWithTools(messages:tools:model:)` - Function calling
  - New types: `ChatResponse`, `ToolCall`
  - Support for text-embedding-3-large (3072 dimensions)

---

## Phase 2: Analytics Pipeline ✅

**Goal**: Process journal entries through the full analytics pipeline: chunking → embedding → analysis → summarization

### 2.1 Text Chunking Service
**Location**: `LifeOS/Core/Services/Analytics/`

- [x] `IngestionService.swift` ✅
  - `chunkEntry(entry: HumanEntry, content: String) -> [JournalChunk]`
  - Split text into ~700-1000 token chunks
  - Smart chunking: respect paragraph boundaries, don't break mid-sentence
  - Token counting using simple heuristics (rough estimate: 1 token ≈ 4 chars)
  - Attach date metadata from entry
  - Track char positions for provenance

### 2.2 Entry-Level Analytics
**Location**: `LifeOS/Core/Services/Analytics/`

- [x] `ChunkAnalyticsSchema.swift` ✅
  - Define JSON schema for chunk analytics extraction
  - Fields: happiness_0_100, valence_-1_to_1, arousal_0_to_1, emotions (joy, sadness, anger, anxiety, gratitude), events, confidence

- [x] `EntryAnalyzer.swift` ✅
  - `analyzeChunk(chunk: JournalChunk) async throws -> ChunkAnalytics`
    - Call OpenAI with structured outputs (JSON Schema)
    - Extract emotions, happiness, events from chunk text
  - `analyzeEntry(entry: HumanEntry, chunks: [JournalChunk]) async throws -> EntryAnalytics`
    - Analyze all chunks for an entry
    - Aggregate chunk analytics using trimmed mean (removes outliers)
    - Merge detected events
    - Calculate overall confidence score
    - Save to database via EntryAnalyticsRepository

- [x] `ChunkAnalytics.swift` (model) ✅
  - Temporary structure for per-chunk analysis results
  - Gets aggregated into EntryAnalytics

### 2.3 Happiness Index Calculator
**Location**: `LifeOS/Core/Services/Analytics/`

- [x] `HappinessIndexCalculator.swift` ✅
  - **Happiness formula**:
    ```
    h = 50 + 30*valence + 10*gratitude + 8*positive_event_density
        - 12*anxiety - 10*rumination - 8*conflict
    ```
  - `computeHappinessScore(valence: Double, emotions: EmotionScores) -> Double`
    - Returns score 0-100
  - `computeMonthlyAggregates(entries: [EntryAnalytics]) -> (avg: Double, ci: (Double, Double))`
    - Robust mean with confidence intervals
    - Filter outliers using IQR method
  - `computeTimeSeriesDataPoints(from: Date, to: Date) async throws -> [TimeSeriesDataPoint]`
    - Generate data points for graphing
  - Bonus: `computeStressScore` and `computeEnergyScore` methods

### 2.4 Hierarchical Summarization
**Location**: `LifeOS/Core/Services/Analytics/`

- [x] `SummarizationService.swift` ✅
  - `summarizeMonth(year: Int, month: Int) async throws -> MonthSummary`
    - Load all EntryAnalytics for the month
    - Use OpenAI to generate summary text (map-reduce)
    - Extract key topics, drivers (positive/negative)
    - Top 5-10 events with sentiment
    - Compute happiness stats with CI
    - Store with source provenance links
  - `summarizeYear(year: Int) async throws -> YearSummary`
    - Load all MonthSummary for the year
    - Generate yearly narrative
    - Top 10-15 events for the year
    - Annual happiness trends
  - Uses structured outputs for consistent format

### 2.5 Pipeline Orchestrator
**Location**: `LifeOS/Core/Services/Analytics/`

- [x] `AnalyticsPipelineService.swift` ✅
  - `processEntry(entry: HumanEntry) async throws`
    - Full pipeline for one entry:
      1. Load entry content via FileManagerService
      2. Chunk text → IngestionService
      3. Generate embeddings → OpenAIService (batch)
      4. Save chunks → ChunkRepository
      5. Analyze entry → EntryAnalyzer
      6. Save analytics → EntryAnalyticsRepository
  - `processAllEntries(progressCallback: (Int, Int) -> Void) async throws`
    - Load all entries from FileManagerService
    - Process each entry
    - Report progress
  - `updateSummaries() async throws`
    - Regenerate all month/year summaries
    - Update time series data
  - `processNewEntry(entry: HumanEntry)` - Optimized for incremental updates
  - Error handling and retry logic

### 2.6 Repository Extensions (Bonus)
**Location**: `LifeOS/Core/Services/Database/`

- [x] `MonthSummaryRepository.swift` ✅
  - CRUD operations for MonthSummary
  - JSON serialization for events and source spans

- [x] `YearSummaryRepository.swift` ✅
  - CRUD operations for YearSummary
  - JSON serialization for events and source spans

---

## Phase 3: ReAct Agent System ⏳

**Goal**: Build a conversational AI agent that can answer questions about your life using the analytics data as tools.

### Prerequisites (From Previous Phases)

**Required Services:**
- ✅ `OpenAIService` - Tool calling support (`chatCompletionWithTools`)
- ✅ `VectorSearchService` - Semantic search capability
- ✅ `HappinessIndexCalculator` - Time series generation
- ✅ `DatabaseService` + all repositories

**Required Models:**
- ✅ `EntryAnalytics` - Entry-level analytics
- ✅ `MonthSummary` / `YearSummary` - Hierarchical summaries
- ✅ `JournalChunk` - Text chunks with embeddings
- ✅ `TimeSeriesDataPoint` - Time series data

**What Phase 3 Adds:**
- 🆕 Agent tools that wrap existing services
- 🆕 Tool registry and orchestration
- 🆕 ReAct loop for reasoning + acting
- 🆕 Current state analysis
- 🆕 Conversational interface

### 3.1 Tool System
**Location**: `LifeOS/Core/Services/Agent/`

- [ ] `AgentTool.swift` (protocol)
  - Properties: `name`, `description`, `parameters` (JSON Schema)
  - Method: `execute(arguments: [String: Any]) async throws -> Any`
  - Base protocol all tools implement

- [ ] Tool Implementations:
  - [ ] `SearchSemanticTool.swift`
    - **Purpose**: Semantic search through journal entries
    - **Parameters**:
      - `query` (string, required) - Natural language search query
      - `startDate` (string, optional) - ISO 8601 date (e.g., "2025-01-01")
      - `endDate` (string, optional) - ISO 8601 date
      - `topK` (integer, optional, default 10) - Number of results
    - **Returns**: Array of chunks with text, date, and similarity score
    - **Dependencies**: VectorSearchService, ChunkRepository, OpenAIService
    - **JSON Schema**:
      ```json
      {
        "type": "function",
        "function": {
          "name": "search_semantic",
          "description": "Search through journal entries using natural language. Use this to find past experiences, feelings, or events.",
          "parameters": {
            "type": "object",
            "properties": {
              "query": {"type": "string", "description": "Natural language search query"},
              "startDate": {"type": "string", "description": "Optional start date (ISO 8601)"},
              "endDate": {"type": "string", "description": "Optional end date (ISO 8601)"},
              "topK": {"type": "integer", "description": "Number of results", "default": 10}
            },
            "required": ["query"]
          }
        }
      }
      ```
    - **Example Input**: `{"query": "times I felt grateful", "topK": 5}`
    - **Example Output**:
      ```json
      [
        {"text": "...", "date": "2025-10-15", "similarity": 0.89, "entryId": "..."},
        ...
      ]
      ```

  - [ ] `GetMonthSummaryTool.swift`
    - **Purpose**: Get AI-generated summary for a specific month
    - **Parameters**:
      - `year` (integer, required) - Year (e.g., 2025)
      - `month` (integer, required) - Month 1-12
    - **Returns**: MonthSummary with narrative, drivers, events, happiness stats
    - **Dependencies**: MonthSummaryRepository
    - **JSON Schema**:
      ```json
      {
        "type": "function",
        "function": {
          "name": "get_month_summary",
          "description": "Get the AI-generated summary for a specific month including narrative, what went well/poorly, and happiness stats.",
          "parameters": {
            "type": "object",
            "properties": {
              "year": {"type": "integer", "description": "Year (e.g., 2025)"},
              "month": {"type": "integer", "description": "Month (1-12)"}
            },
            "required": ["year", "month"]
          }
        }
      }
      ```
    - **Example Input**: `{"year": 2025, "month": 10}`
    - **Example Output**:
      ```json
      {
        "summaryText": "October was a month of...",
        "happinessAvg": 72.5,
        "driversPositive": ["Started new project", "Connected with friends"],
        "driversNegative": ["Work stress", "Sleep issues"],
        "topEvents": [...]
      }
      ```

  - [ ] `GetYearSummaryTool.swift`
    - **Purpose**: Get AI-generated summary for an entire year
    - **Parameters**:
      - `year` (integer, required) - Year (e.g., 2025)
    - **Returns**: YearSummary with narrative and top events
    - **Dependencies**: YearSummaryRepository
    - **JSON Schema**:
      ```json
      {
        "type": "function",
        "function": {
          "name": "get_year_summary",
          "description": "Get the year-in-review summary with major themes and events.",
          "parameters": {
            "type": "object",
            "properties": {
              "year": {"type": "integer", "description": "Year (e.g., 2025)"}
            },
            "required": ["year"]
          }
        }
      }
      ```

  - [ ] `GetTimeSeriesTool.swift`
    - **Purpose**: Get happiness/stress/energy time series data for graphing
    - **Parameters**:
      - `metric` (string, required) - "happiness", "stress", or "energy"
      - `fromDate` (string, required) - ISO 8601 start date
      - `toDate` (string, required) - ISO 8601 end date
    - **Returns**: Array of TimeSeriesDataPoint with dates and values
    - **Dependencies**: HappinessIndexCalculator, EntryAnalyticsRepository
    - **JSON Schema**:
      ```json
      {
        "type": "function",
        "function": {
          "name": "get_time_series",
          "description": "Get time series data for happiness, stress, or energy over a date range.",
          "parameters": {
            "type": "object",
            "properties": {
              "metric": {"type": "string", "enum": ["happiness", "stress", "energy"]},
              "fromDate": {"type": "string", "description": "Start date (ISO 8601)"},
              "toDate": {"type": "string", "description": "End date (ISO 8601)"}
            },
            "required": ["metric", "fromDate", "toDate"]
          }
        }
      }
      ```

  - [ ] `GetCurrentStateSnapshotTool.swift`
    - **Purpose**: Analyze current life state based on recent entries
    - **Parameters**:
      - `days` (integer, optional, default 30) - Number of recent days to analyze
    - **Returns**: CurrentState with themes, mood trends, stressors, protective factors, suggested todos
    - **Dependencies**: CurrentStateAnalyzer
    - **JSON Schema**:
      ```json
      {
        "type": "function",
        "function": {
          "name": "get_current_state",
          "description": "Analyze current life state including themes, mood, stressors, and get AI-suggested action items.",
          "parameters": {
            "type": "object",
            "properties": {
              "days": {"type": "integer", "description": "Number of recent days", "default": 30}
            }
          }
        }
      }
      ```

- [ ] `ToolRegistry.swift`
  - Central registry of all available tools
  - `registerTool(tool: AgentTool)` - Add a tool
  - `getToolSchemas() -> [[String: Any]]` - Get OpenAI function definitions
  - `executeTool(name: String, arguments: [String: Any]) async throws -> Any` - Execute by name
  - Validates tool arguments against schemas

### 3.2 Agent Kernel (ReAct Loop)
**Location**: `LifeOS/Core/Services/Agent/`

- [ ] `AgentMessage.swift` (model)
  - Enum: `.user(String)`, `.assistant(String)`, `.toolCall(ToolCall)`, `.toolResult(String, Any)`
  - Converts to/from OpenAI message format

- [ ] `AgentKernel.swift`
  - **Main ReAct loop**: Reasoning + Acting
  - `runAgent(userMessage: String, conversationHistory: [AgentMessage]) async throws -> AgentResponse`
    1. Build messages array with system prompt + history + user message
    2. Call OpenAI with tools using `chatCompletionWithTools`
    3. If response has tool calls:
       - Execute each tool via ToolRegistry
       - Add tool results to messages
       - Loop back to step 2 (max 10 iterations)
    4. Return final text response
  - `buildSystemPrompt() -> String` - See template below
  - Max iterations safety limit (prevent infinite loops)
  - Error handling for tool failures

**System Prompt Template**:
```
You are a thoughtful AI assistant with access to the user's complete journal history and analytics.

Your purpose is to help the user understand their emotional patterns, reflect on their experiences, and gain insights about their life.

## Available Tools

You have access to the following tools:

1. **search_semantic**: Search through journal entries using natural language
   - Use when the user asks about past experiences, feelings, or memories
   - Example: "When did I last feel anxious about work?"

2. **get_month_summary**: Get AI-generated summary for a specific month
   - Use when the user asks about "how was [month]" or wants an overview
   - Returns narrative, positive/negative drivers, top events, happiness stats

3. **get_year_summary**: Get year-in-review summary
   - Use for annual reflections or "how was [year]"

4. **get_time_series**: Get happiness/stress/energy trends over time
   - Use when user asks about trends, patterns, or "how have I been feeling"
   - Can show happiness, stress, or energy metrics

5. **get_current_state**: Analyze current life state with themes, mood, and suggested actions
   - Use when user asks "how am I doing?" or wants actionable advice
   - Returns themes, stressors, protective factors, and AI-suggested todos

## Guidelines

- Be warm, empathetic, and non-judgmental
- Use tools proactively to provide evidence-based insights
- When sharing journal excerpts, be respectful and thoughtful
- Provide actionable suggestions when appropriate
- If uncertain, use semantic search to find relevant context
- Keep responses concise but insightful (2-4 paragraphs)
- Use specific examples and data from the journal when available

## Response Style

- Start with empathy and understanding
- Support claims with specific evidence (dates, events, metrics)
- End with reflection questions or gentle suggestions when appropriate
- Avoid being preachy or prescriptive
```

- [ ] `AgentResponse.swift` (model)
  - `text: String` - Final answer to user
  - `toolsUsed: [String]` - Names of tools called
  - `metadata: [String: Any]` - Extra info (iterations, tokens used, etc.)

**Agent Conversation Flow**:
```
User: "How have I been feeling this month?"
    ↓
AgentKernel.runAgent()
    ↓
[Build messages: system prompt + history + user message]
    ↓
OpenAI API (with tools)
    ↓
Model Response: tool_calls = [
  {name: "get_month_summary", args: {year: 2025, month: 10}},
  {name: "get_time_series", args: {metric: "happiness", from: "2025-10-01", to: "2025-10-22"}}
]
    ↓
ToolRegistry.executeTool("get_month_summary", ...)
  → MonthSummaryRepository.get(2025, 10)
  → Result: {summaryText: "...", happinessAvg: 72.5, ...}
    ↓
ToolRegistry.executeTool("get_time_series", ...)
  → HappinessIndexCalculator.computeTimeSeriesDataPoints(...)
  → Result: [{date: "2025-10-01", value: 68}, ...]
    ↓
[Add tool results to conversation]
    ↓
OpenAI API (with tools) - Second iteration
    ↓
Model Response: "Based on your October journal entries, your happiness has been..."
    ↓
Return AgentResponse
    ↓
User sees response
```

**Example Conversation**:
```
User: "What made me happy last month?"

Agent thinks: Need to search for positive experiences
  → Calls: search_semantic({query: "felt happy, joyful moments", fromDate: "2025-09-01", toDate: "2025-09-30"})
  → Gets: 5 journal chunks about hiking, time with friends, project success

Agent responds:
"Last month, three main things brought you joy:

1. **Outdoor activities** - You wrote about feeling energized after hiking on Sept 12th and 19th
2. **Social connections** - Coffee with Sarah (Sept 8th) and game night (Sept 23rd) both stood out as highlights
3. **Work wins** - Completing the new feature (Sept 15th) gave you a real sense of accomplishment

Your happiness peaked around Sept 19-23, averaging 78/100 during that week. What aspects of these experiences would you like to bring more of into this month?"
```

**Implementation Examples**:

1. **Registering Tools**:
```swift
let toolRegistry = ToolRegistry()

// Create tool instances with dependencies
let searchTool = SearchSemanticTool(
    vectorSearch: VectorSearchService(),
    chunkRepository: ChunkRepository(),
    openAI: OpenAIService()
)

let monthSummaryTool = GetMonthSummaryTool(
    repository: MonthSummaryRepository()
)

// Register all tools
toolRegistry.registerTool(searchTool)
toolRegistry.registerTool(monthSummaryTool)
toolRegistry.registerTool(GetYearSummaryTool(...))
toolRegistry.registerTool(GetTimeSeriesTool(...))
toolRegistry.registerTool(GetCurrentStateSnapshotTool(...))
```

2. **Running the Agent**:
```swift
let agent = AgentKernel(
    openAI: OpenAIService(),
    toolRegistry: toolRegistry
)

// Simple question
let response = try await agent.runAgent(
    userMessage: "How have I been feeling this month?",
    conversationHistory: []
)

print(response.text)
print("Tools used:", response.toolsUsed)
```

3. **Conversation with History**:
```swift
var history: [AgentMessage] = []

// First question
let response1 = try await agent.runAgent(
    userMessage: "What made me stressed last week?",
    conversationHistory: history
)
history.append(.user("What made me stressed last week?"))
history.append(.assistant(response1.text))

// Follow-up question (agent has context)
let response2 = try await agent.runAgent(
    userMessage: "What can I do about it?",
    conversationHistory: history
)
```

### 3.3 Current State Analyzer
**Location**: `LifeOS/Core/Services/Agent/`

- [ ] `CurrentState.swift` (model)
  - `themes: [String]` - Top 3-5 current themes
  - `mood: MoodState` - happiness, stress, energy levels with trends
  - `stressors: [String]` - Active stressors
  - `protectiveFactors: [String]` - What's going well
  - `suggestedTodos: [AISuggestedTodo]` - AI-generated action items
  - Codable for storage

- [ ] `MoodState.swift` (model)
  - `happiness: Double`, `stress: Double`, `energy: Double`
  - `trend: Trend` - enum: up, down, stable
  - Recent 7-day vs previous 7-day comparison

- [ ] `AISuggestedTodo.swift` (model)
  - `title: String`, `firstStep: String`, `whyItMatters: String`
  - `theme: String` - grouping (health, relationships, work, etc.)
  - `estimatedMinutes: Int`
  - Can convert to existing `TODOItem` model

- [ ] `CurrentStateAnalyzer.swift`
  - `analyze(days: Int = 30) async throws -> CurrentState`
    - Load last N days of EntryAnalytics
    - Call OpenAI with structured outputs
    - JSON schema ensures consistent format
    - Extract themes using topic modeling approach
    - Compute mood trends from time series
    - Generate 5-10 actionable todos grouped by theme
  - Uses `chatCompletion<CurrentState>` with schema
  - **Dependencies**: EntryAnalyticsRepository, HappinessIndexCalculator

**CurrentState JSON Schema**:
```json
{
  "name": "current_state",
  "strict": true,
  "schema": {
    "type": "object",
    "properties": {
      "themes": {
        "type": "array",
        "items": {"type": "string"},
        "description": "Top 3-5 themes in recent journal entries"
      },
      "mood": {
        "type": "object",
        "properties": {
          "happiness": {"type": "number", "description": "Current happiness 0-100"},
          "stress": {"type": "number", "description": "Current stress 0-100"},
          "energy": {"type": "number", "description": "Current energy 0-100"},
          "happinessTrend": {"type": "string", "enum": ["up", "down", "stable"]},
          "stressTrend": {"type": "string", "enum": ["up", "down", "stable"]},
          "energyTrend": {"type": "string", "enum": ["up", "down", "stable"]}
        },
        "required": ["happiness", "stress", "energy", "happinessTrend", "stressTrend", "energyTrend"]
      },
      "stressors": {
        "type": "array",
        "items": {"type": "string"},
        "description": "Active stressors/challenges (3-5 items)"
      },
      "protectiveFactors": {
        "type": "array",
        "items": {"type": "string"},
        "description": "Things going well/protective factors (3-5 items)"
      },
      "suggestedTodos": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "title": {"type": "string"},
            "firstStep": {"type": "string"},
            "whyItMatters": {"type": "string"},
            "theme": {"type": "string"},
            "estimatedMinutes": {"type": "integer"}
          },
          "required": ["title", "firstStep", "whyItMatters", "theme", "estimatedMinutes"]
        },
        "description": "5-10 AI-suggested action items"
      }
    },
    "required": ["themes", "mood", "stressors", "protectiveFactors", "suggestedTodos"]
  }
}
```

**Example CurrentState Output**:
```json
{
  "themes": ["Career growth", "Health & fitness", "Social connections", "Financial planning"],
  "mood": {
    "happiness": 72,
    "stress": 45,
    "energy": 68,
    "happinessTrend": "up",
    "stressTrend": "stable",
    "energyTrend": "down"
  },
  "stressors": [
    "Upcoming project deadline",
    "Not sleeping well",
    "Financial uncertainty"
  ],
  "protectiveFactors": [
    "Regular exercise routine",
    "Strong friend support",
    "Making progress on side project"
  ],
  "suggestedTodos": [
    {
      "title": "Break down project into smaller tasks",
      "firstStep": "List all project deliverables in a document",
      "whyItMatters": "Reduce overwhelm by having a clear roadmap",
      "theme": "work",
      "estimatedMinutes": 30
    },
    {
      "title": "Establish consistent bedtime routine",
      "firstStep": "Set a phone alarm for 30min before target bedtime",
      "whyItMatters": "Better sleep will improve energy and mood",
      "theme": "health",
      "estimatedMinutes": 15
    }
  ]
}
```

---

## Phase 4: UI Features ⏳

**Goal**: Build user interfaces for visualizing analytics and chatting with the AI agent.

### 4.1 Analytics Dashboard
**Location**: `LifeOS/Features/Analytics/`

- [ ] `AnalyticsView.swift`
  - Main analytics dashboard container
  - Tab navigation: **Overview** | **Happiness** | **Timeline** | **Insights**
  - Toolbar with date range picker, export button
  - Empty state if no analytics processed yet

- [ ] `AnalyticsViewModel.swift`
  - `@Published var timeSeries: [TimeSeriesDataPoint]`
  - `@Published var selectedDateRange: DateInterval`
  - `loadAnalytics() async`
  - `refreshAnalytics() async`
  - Coordinate with DatabaseService, HappinessIndexCalculator

- [ ] **Overview Tab** - `AnalyticsOverviewView.swift`
  - Key metrics cards: current happiness, 30-day average, trend
  - Mini happiness chart (last 90 days)
  - Recent highlights (top 3 positive/negative events)

- [ ] **Happiness Tab** - `HappinessChartView.swift`
  - Full-screen time series chart using **SwiftUI Charts**
  - Interactive: tap data point → show that day's entry
  - Show confidence intervals as shaded area
  - Zoom controls (1M, 3M, 6M, 1Y, ALL)
  - Annotations for major events

- [ ] **Timeline Tab** - `TimelineView.swift`
  - Year → Month → Week drill-down hierarchy
  - Horizontal timeline visualization
  - Events color-coded by sentiment (green=positive, red=negative)
  - Tap month → show MonthDetailView

- [ ] `MonthDetailView.swift` (sheet/detail view)
  - Month summary text
  - Happiness stats with CI
  - Key topics as chips
  - Drivers: positive (green) and negative (red) lists
  - Top events table with dates and descriptions
  - "Show Evidence" buttons → navigate to source entry in EntryListView

- [ ] **Insights Tab** - `AnalyticsInsightsView.swift`
  - Correlations (e.g., "Happiness higher when...")
  - Patterns (e.g., "You tend to feel better on weekends")
  - Growth metrics (e.g., "30% improvement since last quarter")
  - Future: ML-powered insights

### 4.2 AI Chat Interface
**Location**: `LifeOS/Features/AIChat/`

- [ ] `AIChatView.swift`
  - Full-screen chat interface
  - `ScrollView` with message bubbles
  - Text input field at bottom with send button
  - Loading indicator while agent is thinking
  - "Tools used" badges below AI responses
  - Conversation persistence (save/load from UserDefaults or database)

- [ ] `MessageBubbleView.swift`
  - User messages: right-aligned, blue background
  - AI messages: left-aligned, gray background
  - Markdown rendering for formatted text
  - Special rendering for structured data:
    - Todo lists → checkbox UI
    - Time series data → inline mini chart
    - Events → timeline snippets
  - Copy button for AI responses

- [ ] `AIChatViewModel.swift`
  - `@Published var messages: [AgentMessage]`
  - `@Published var isLoading: Bool`
  - `sendMessage(text: String) async`
    - Call AgentKernel.runAgent
    - Append user message
    - Append AI response
  - `clearConversation()`
  - Save conversation to UserDefaults for persistence

### 4.3 Current State Dashboard
**Location**: `LifeOS/Features/Dashboard/`

- [ ] `CurrentStateDashboardView.swift`
  - Compact widget showing current life state
  - **Header**: "How you're doing right now" with refresh button
  - **Mood section**: Happiness/Stress/Energy gauges with trend arrows
  - **Themes section**: Chips for top 3-5 themes (color-coded)
  - **Stressors section**: Red-outlined list
  - **Protective factors section**: Green-outlined list
  - Refresh every time view appears (cache for 1 hour)

- [ ] `AISuggestedTodosView.swift`
  - "AI Suggestions" header with sparkle icon ✨
  - Grouped todos by theme (collapsible sections)
  - Each todo card shows:
    - Title
    - First step (smaller font)
    - "Why it matters" (tooltip or expandable)
    - Estimated time badge
    - "+" button to add to today's journal entry
  - Integration with existing TODO system

- [ ] `CurrentStateDashboardViewModel.swift`
  - `@Published var currentState: CurrentState?`
  - `@Published var isLoading: Bool`
  - `loadCurrentState() async`
    - Call CurrentStateAnalyzer
    - Update UI
  - `addTodoToJournal(todo: AISuggestedTodo)`
    - Find or create today's entry
    - Add as TODOItem

- [ ] **Integration Point**
  - Add new sidebar item "Insights" below "Calendar"
  - Or add as tab in existing CalendarView
  - Route: `/insights`

---

## Phase 5: Background Processing & Settings ⏳

**Goal**: Handle long-running analytics tasks in the background with progress UI and user controls.

### 5.1 Background Task System
**Location**: `LifeOS/Core/Services/Background/`

- [ ] `BackgroundTaskService.swift`
  - Task queue using `OperationQueue`
  - Priority management (high, normal, low)
  - `addTask(operation: Operation)` - Queue a task
  - `cancelAllTasks()` - Cancel all pending tasks
  - `@Published var activeTaskCount: Int`
  - Singleton pattern for global access

- [ ] `AnalyticsProcessingTask.swift` (subclass of Operation)
  - Wraps `AnalyticsPipelineService.processAllEntries`
  - Reports progress via progress object
  - `progress: Progress` - Foundation Progress object (0-100%)
  - Cancellable
  - Error handling with retry logic

- [ ] `SummarizationTask.swift` (subclass of Operation)
  - Wraps `SummarizationService.updateSummaries`
  - Depends on AnalyticsProcessingTask completion
  - Reports progress

### 5.2 Progress UI & Controls
**Location**: `LifeOS/Features/Settings/` (extend existing)

- [ ] Update `SettingsView.swift`
  - Add **"Analytics"** section
  - **"Process All Entries"** button
    - Triggers AnalyticsProcessingTask
    - Shows AnalyticsProgressView as sheet
    - Disabled if already processing
  - **"Recompute Summaries"** button
    - Triggers SummarizationTask
  - **"Clear All Analytics"** button (dangerous, confirmation dialog)
    - Calls DatabaseService.clearAllData()
  - **Storage stats**:
    - Total entries: X
    - Entries analyzed: Y
    - Database size: Z MB
    - Last processed: date

- [ ] `AnalyticsProgressView.swift` (sheet/modal)
  - Title: "Processing Journal Entries"
  - Progress bar (0-100%)
  - Status text: "Processing entry 45 of 320..."
  - Current operation: "Analyzing emotions..."
  - Elapsed time counter
  - Estimated time remaining (based on rate)
  - **Cancel button** (confirmation: "This will stop processing. Continue?")
  - Auto-dismiss on completion with success message

- [ ] `AnalyticsSettingsViewModel.swift`
  - `@Published var isProcessing: Bool`
  - `@Published var progress: Double` (0-1)
  - `@Published var statusText: String`
  - `@Published var storageStats: AnalyticsStorageStats`
  - `startProcessing() async`
  - `cancelProcessing()`
  - `loadStorageStats() async`

- [ ] `AnalyticsStorageStats.swift` (model)
  - `totalEntries: Int`
  - `analyzedEntries: Int`
  - `databaseSizeBytes: Int`
  - `lastProcessedDate: Date?`

### 5.3 Automatic Processing Triggers

- [ ] Extend `FileManagerService.swift`
  - After saving a new entry, trigger single-entry processing
  - `NotificationCenter.post` "EntryDidSave" notification

- [ ] Create `AnalyticsObserver.swift`
  - Listens for "EntryDidSave" notification
  - Automatically processes new entries in background
  - Debounce rapid saves (wait 5 seconds before processing)
  - Only process if user has analytics enabled (user preference)

---

## Dependencies

### Swift Package Manager
Add to `LifeOS.xcodeproj`:
- [x] **GRDB.swift** - SQLite toolkit ✅
  - Repository: `https://github.com/groue/GRDB.swift`
  - Version: 6.x.x (latest stable)
  - **Status**: Added manually in Xcode

---

## Data Flow Architecture

```
Journal Entry (FileManagerService)
    ↓
Chunking (IngestionService)
    ↓
Embedding (EmbeddingService → OpenAI API)
    ↓
Storage (DatabaseService → SQLite)
    ↓
Analytics (EntryAnalyzer → OpenAI API with Structured Outputs)
    ↓
Summarization (SummarizationService → OpenAI API)
    ↓
Storage (DatabaseService → month_summaries, year_summaries, time_series)
    ↓
Agent Tools ← Query Interface
    ↓
Agent Kernel (ReAct Loop)
    ↓
UI (Analytics, Chat, Dashboard)
```

---

## API Endpoints Used

### OpenAI API Calls
1. **Embeddings**: `POST /v1/embeddings`
   - Model: `text-embedding-3-large`
   - For: Chunk vectorization

2. **Chat Completions**: `POST /v1/chat/completions`
   - Model: `gpt-4o` (or `gpt-4o-mini` for cost)
   - For: Analytics, summarization, agent responses
   - Features: Structured Outputs, Tool Calling, Streaming

---

## Testing Strategy

### Unit Tests
- [ ] `LifeOSTests/Analytics/ChunkingTests.swift`
- [ ] `LifeOSTests/Analytics/HappinessCalculatorTests.swift`
- [ ] `LifeOSTests/Database/DatabaseServiceTests.swift`
- [ ] `LifeOSTests/Agent/ToolRegistryTests.swift`

### Integration Tests
- [ ] End-to-end: Entry → Analytics → Chat
- [ ] Database migrations
- [ ] Vector search accuracy

---

## Privacy & Security Considerations

- ✅ All journal data stays encrypted on disk (existing EncryptionService)
- ✅ SQLite database will also be encrypted
- ✅ No journal content sent to OpenAI except for processing (user controls when)
- ✅ API keys stored in Keychain (existing KeychainService)
- ⚠️ User should understand: Journal chunks sent to OpenAI for embedding/analysis
- 🔒 Consider: Option to disable cloud processing (local-only mode)

---

## Performance Targets

- **Initial ingestion**: Process 100 entries in < 5 minutes
- **Incremental updates**: Process 1 new entry in < 10 seconds
- **Vector search**: Return top 10 results in < 100ms
- **Chat response**: First token in < 2 seconds
- **UI responsiveness**: Never block main thread

---

## Cost Estimates (OpenAI API)

### One-Time Ingestion (300k tokens)
- Embeddings: ~300k tokens × $0.13/1M = $0.039
- Analytics: ~300k tokens input + 30k output = $0.50-$1.00
- Summarization: ~50k tokens = $0.10
- **Total**: ~$1.50 for full history

### Ongoing (per new entry ~500 tokens)
- Embedding: ~$0.00007
- Analytics: ~$0.002
- **Total**: ~$0.002 per entry

### Chat Usage
- $0.01-$0.05 per conversation (5-10 turns)

---

## Next Steps

1. **Phase 1.1**: Create data models
2. **Phase 1.2**: Set up GRDB and database schema
3. **Phase 1.3**: Implement vector search
4. **Phase 2**: Build analytics pipeline
5. **Phase 3**: Implement agent system
6. **Phase 4**: Build UI features
7. **Phase 5**: Add background processing

---

## Questions & Decisions

- [ ] Should happiness forecasting use simple time series or train a local ML model?
  - **Decision**: Start with simple exponential smoothing, upgrade later if needed

- [ ] Embedding model: text-embedding-3-large vs small?
  - **Decision**: Use large for better quality (cost difference minimal)

- [ ] Agent model: GPT-4o vs GPT-4o-mini?
  - **Decision**: Use 4o for agent kernel, 4o-mini for analytics to reduce cost

- [ ] How to handle entries without clear dates?
  - **Decision**: Use file creation timestamp as fallback

- [ ] Database location?
  - **Decision**: Same directory as encrypted journal files for portability

---

## Progress Legend
- ⏳ Not started
- 🚧 In progress
- ✅ Complete
- ⚠️ Blocked/Needs decision
