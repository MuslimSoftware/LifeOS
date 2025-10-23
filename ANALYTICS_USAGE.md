# LifeOS Analytics System - Usage Guide

## Overview

The LifeOS Analytics System is a pure Swift journal analytics pipeline that processes your journal entries to extract emotions, compute happiness metrics, detect events, and generate insightful summaries. It uses OpenAI's API for embeddings and analysis while keeping all your data encrypted locally.

**Key Capabilities:**
- 📊 **Emotional Analysis** - Extract joy, sadness, anger, anxiety, and gratitude from journal text
- 😊 **Happiness Scoring** - Quantified happiness metrics (0-100 scale) with confidence intervals
- 📅 **Event Detection** - Automatically identify significant life events with sentiment
- 📈 **Time Series Data** - Track happiness, stress, and energy over time
- 📝 **Smart Summaries** - AI-generated monthly and yearly narrative summaries
- 🔍 **Semantic Search** - Vector-based search through your entire journal history

---

## Architecture

```
Journal Entry
    ↓ Load Content
IngestionService
    ↓ Chunk Text (700-1000 tokens)
OpenAIService
    ↓ Generate Embeddings
ChunkRepository
    ↓ Store Chunks + Vectors
EntryAnalyzer
    ↓ Extract Emotions/Events (OpenAI Structured Outputs)
EntryAnalyticsRepository
    ↓ Store Analytics
HappinessIndexCalculator
    ↓ Compute Scores
SummarizationService
    ↓ Generate Monthly/Yearly Summaries
MonthSummaryRepository + YearSummaryRepository
    ✓ Complete!
```

---

## Quick Start

### 1. Initialize Services

```swift
import Foundation

// Initialize database service (singleton)
let dbService = DatabaseService.shared

// Initialize repositories
let chunkRepo = ChunkRepository(dbService: dbService)
let analyticsRepo = EntryAnalyticsRepository(dbService: dbService)
let monthSummaryRepo = MonthSummaryRepository(dbService: dbService)
let yearSummaryRepo = YearSummaryRepository(dbService: dbService)

// Initialize file manager service
let fileManager = FileManagerService()

// Initialize pipeline
let pipeline = AnalyticsPipelineService(
    fileManagerService: fileManager,
    chunkRepository: chunkRepo,
    analyticsRepository: analyticsRepo,
    monthSummaryRepository: monthSummaryRepo,
    yearSummaryRepository: yearSummaryRepo
)
```

---

## Common Operations

### Process a Single Entry

Process a newly created journal entry through the complete analytics pipeline:

```swift
// Assuming you have a HumanEntry object
let entry = HumanEntry.createNew()

// Process the entry (async)
Task {
    do {
        try await pipeline.processEntry(entry)
        print("✅ Entry processed successfully")
    } catch {
        print("❌ Error processing entry: \(error)")
    }
}
```

**What happens:**
1. Loads entry content from disk (encrypted)
2. Chunks text into ~700-1000 token segments
3. Generates embeddings for each chunk via OpenAI
4. Saves chunks with embeddings to database
5. Analyzes each chunk to extract emotions/events
6. Aggregates chunk analytics into entry-level analytics
7. Saves analytics to database

**Time:** ~5-15 seconds per entry (depends on entry length)

---

### Process All Entries (Bulk)

Process your entire journal history:

```swift
Task {
    do {
        try await pipeline.processAllEntries { current, total in
            print("Processing \(current)/\(total)")
            // Update UI progress bar here
        }
        print("✅ All entries processed!")
    } catch {
        print("❌ Error: \(error)")
    }
}
```

**Performance:**
- Processes ~100 entries in 5-10 minutes
- Includes 0.5s delay between entries to avoid rate limiting
- Continues on error (skips failed entries)

---

### Generate Summaries

After processing entries, generate monthly and yearly summaries:

```swift
Task {
    do {
        try await pipeline.updateSummaries()
        print("✅ Summaries updated!")
    } catch {
        print("❌ Error: \(error)")
    }
}
```

**What happens:**
1. Identifies all months with analytics data
2. Generates narrative summary for each month
3. Extracts positive/negative drivers
4. Computes happiness statistics
5. Generates yearly summaries from monthly data

---

### Query Analytics

#### Get Analytics for a Specific Entry

```swift
let entryId = UUID(uuidString: "...")!

do {
    if let analytics = try analyticsRepo.get(forEntryId: entryId) {
        print("Happiness: \(analytics.happinessScore)")
        print("Valence: \(analytics.valence)")
        print("Emotions: \(analytics.emotions)")
        print("Events: \(analytics.events)")
    }
} catch {
    print("Error: \(error)")
}
```

#### Get Analytics for a Date Range

```swift
let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
let endDate = Date()

do {
    let analytics = try analyticsRepo.getAnalytics(from: startDate, to: endDate)
    print("Found \(analytics.count) entries")

    let avgHappiness = analytics.map { $0.happinessScore }.reduce(0, +) / Double(analytics.count)
    print("Average happiness: \(avgHappiness)")
} catch {
    print("Error: \(error)")
}
```

#### Get Monthly Summary

```swift
do {
    if let summary = try monthSummaryRepo.get(year: 2025, month: 10) {
        print("Summary: \(summary.summaryText)")
        print("Avg Happiness: \(summary.happinessAvg)")
        print("Positive Drivers: \(summary.driversPositive)")
        print("Negative Drivers: \(summary.driversNegative)")
        print("Top Events: \(summary.topEvents.count)")
    }
} catch {
    print("Error: \(error)")
}
```

#### Get Yearly Summary

```swift
do {
    if let summary = try yearSummaryRepo.get(year: 2025) {
        print("Year Review: \(summary.summaryText)")
        print("Avg Happiness: \(summary.happinessAvg)")
        print("Top Events: \(summary.topEvents)")
    }
} catch {
    print("Error: \(error)")
}
```

---

### Compute Time Series Data

Generate data points for graphing happiness over time:

```swift
let calculator = HappinessIndexCalculator()
let startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
let endDate = Date()

Task {
    do {
        let dataPoints = try await calculator.computeTimeSeriesDataPoints(
            from: startDate,
            to: endDate,
            repository: analyticsRepo
        )

        for point in dataPoints {
            print("\(point.date): \(point.value) (confidence: \(point.confidence))")
        }

        // Use dataPoints for SwiftUI Charts
    } catch {
        print("Error: \(error)")
    }
}
```

---

### Semantic Search

Search through journal entries using natural language:

```swift
let vectorSearch = VectorSearchService()
let openAI = OpenAIService()

Task {
    do {
        // Generate query embedding
        let queryEmbedding = try await openAI.generateEmbedding(for: "times I felt grateful")

        // Load all chunks from database
        let allChunks = try chunkRepo.getAll()

        // Search for top 10 most similar chunks
        let results = vectorSearch.semanticSearch(
            query: queryEmbedding,
            chunks: allChunks,
            topK: 10,
            minSimilarity: 0.7
        )

        for result in results {
            print("Similarity: \(result.similarity)")
            print("Text: \(result.chunk.text)")
            print("Date: \(result.chunk.date)")
            print("---")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

---

## Understanding the Data Models

### EntryAnalytics

Complete analytics for a single journal entry:

```swift
struct EntryAnalytics {
    let entryId: UUID
    let date: Date
    let happinessScore: Double      // 0-100
    let valence: Double             // -1 to 1 (negative to positive)
    let arousal: Double             // 0 to 1 (calm to excited)
    let emotions: EmotionScores     // joy, sadness, anger, anxiety, gratitude
    let events: [DetectedEvent]     // detected events
    let confidence: Double          // 0-1 (analysis confidence)
}
```

### EmotionScores

Normalized emotion intensities (0-1 scale):

```swift
struct EmotionScores {
    let joy: Double
    let sadness: Double
    let anger: Double
    let anxiety: Double
    let gratitude: Double
}
```

### DetectedEvent

Events automatically extracted from journal text:

```swift
struct DetectedEvent {
    let title: String               // "Had coffee with Sarah"
    let date: Date?                 // Optional specific date
    let description: String?        // Optional details
    let sentiment: String           // "positive", "negative", "neutral"
}
```

### MonthSummary

AI-generated monthly summary:

```swift
struct MonthSummary {
    let year: Int
    let month: Int
    let summaryText: String                    // 2-3 sentence narrative
    let happinessAvg: Double                   // Average happiness
    let happinessCI: (Double, Double)          // 95% confidence interval
    let driversPositive: [String]              // What went well
    let driversNegative: [String]              // Challenges
    let topEvents: [DetectedEvent]             // Top 5-10 events
    let sourceSpans: [SourceSpan]              // Provenance links
}
```

---

## The Happiness Formula

The happiness score (0-100) is computed using:

```
h = 50 + 30*valence + 10*gratitude + 8*positive_event_density
    - 12*anxiety - 10*sadness - 8*anger
```

**Components:**
- **Valence** (-1 to 1): Overall emotional positivity
- **Gratitude** (0-1): Intensity of gratitude expressed
- **Anxiety** (0-1): Intensity of anxiety/worry
- **Sadness** (0-1): Intensity of sadness (proxy for rumination)
- **Anger** (0-1): Intensity of anger (proxy for conflict)

The formula is implemented in `HappinessIndexCalculator.swift`.

---

## Advanced Usage

### Compute Custom Metrics

```swift
let calculator = HappinessIndexCalculator()

// Get stress score (0-100)
let stressScore = calculator.computeStressScore(analytics: entryAnalytics)

// Get energy score (0-100)
let energyScore = calculator.computeEnergyScore(analytics: entryAnalytics)
```

### Process New Entry Incrementally

Optimized for single entry with automatic summary update:

```swift
Task {
    do {
        try await pipeline.processNewEntry(entry)
        // Automatically updates the relevant month summary
    } catch {
        print("Error: \(error)")
    }
}
```

### Clear All Analytics Data

```swift
do {
    try DatabaseService.shared.clearAllData()
    print("✅ All analytics data cleared")
} catch {
    print("Error: \(error)")
}
```

---

## Performance & Cost

### Processing Performance
- **Single entry**: 5-15 seconds
- **100 entries**: 5-10 minutes
- **Vector search**: <100ms for 10,000 chunks

### OpenAI API Costs (Estimates)

**One-time full ingestion (300k tokens):**
- Embeddings: ~$0.04
- Analytics: ~$0.50-$1.00
- Summarization: ~$0.10
- **Total: ~$1.50**

**Ongoing per entry (~500 tokens):**
- ~$0.002 per entry

**Chat/search:**
- ~$0.01-$0.05 per conversation

---

## Error Handling

All async operations can throw errors. Common errors:

```swift
// Pipeline errors
enum PipelineError: Error {
    case failedToLoadEntry(String)
}

// Analytics errors
enum AnalyticsError: Error {
    case noChunksToAnalyze
    case allChunksFailedAnalysis
}

// Summarization errors
enum SummarizationError: Error {
    case noDataForPeriod
}

// OpenAI errors
enum OpenAIError: Error {
    case noAPIKey
    case networkError(String)
    case invalidResponse
}
```

---

## Privacy & Security

- ✅ All journal data encrypted on disk (AES-GCM)
- ✅ SQLite database also encrypted
- ✅ API keys stored in Keychain
- ⚠️ Journal chunks sent to OpenAI for embedding/analysis
- ℹ️ No data stored on OpenAI servers (per API terms)

---

## Next Steps

- **Phase 3**: ReAct Agent System - AI chat interface with tool calling
- **Phase 4**: UI Features - Analytics dashboard, graphs, insights view
- **Phase 5**: Background Processing - Automated processing with progress UI

---

## Troubleshooting

### "No API key found"
Ensure OpenAI API key is set in Settings → OpenAI API Key

### "All chunks failed analysis"
Check network connection and API key validity. May indicate rate limiting.

### "No analytics data available"
Run `pipeline.processAllEntries()` first to generate analytics data.

### Slow processing
Processing is rate-limited to 0.5s between entries to avoid API throttling. This is intentional.

---

## Reference

For implementation details and technical architecture, see:
- `ANALYTICS_IMPLEMENTATION.md` - Full implementation tracker
- Phase 1: Core infrastructure (models, database, vector search)
- Phase 2: Analytics pipeline (chunking, analysis, summarization)
- Phase 3: ReAct Agent System (coming soon)
