import Foundation

/// Service for analyzing journal chunks and entries to extract emotional metrics
/// Uses OpenAI API with structured outputs for consistent analysis
class EntryAnalyzer {

    private let openAIService: OpenAIService
    private let analyticsRepository: EntryAnalyticsRepository

    init(
        openAIService: OpenAIService = OpenAIService(),
        analyticsRepository: EntryAnalyticsRepository
    ) {
        self.openAIService = openAIService
        self.analyticsRepository = analyticsRepository
    }

    // MARK: - Chunk Analysis

    func analyzeChunk(_ chunk: JournalChunk) async throws -> ChunkAnalytics {
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": ChunkAnalyticsSchema.systemPrompt
            ],
            [
                "role": "user",
                "content": "Analyze this journal entry text:\n\n\(chunk.text)"
            ]
        ]

        let analytics: ChunkAnalytics = try await openAIService.chatCompletion(
            messages: messages,
            schema: ChunkAnalyticsSchema.schema,
            model: "gpt-4o-mini"
        )

        return analytics
    }

    // MARK: - Entry Analysis

    func analyzeEntry(entry: HumanEntry, chunks: [JournalChunk]) async throws -> EntryAnalytics {
        guard !chunks.isEmpty else {
            throw AnalyticsError.noChunksToAnalyze
        }

        var chunkAnalytics: [ChunkAnalytics] = []
        for chunk in chunks {
            do {
                let analytics = try await analyzeChunk(chunk)
                chunkAnalytics.append(analytics)
            } catch {
                print("⚠️ Failed to analyze chunk \(chunk.id): \(error)")
            }
        }

        guard !chunkAnalytics.isEmpty else {
            throw AnalyticsError.allChunksFailedAnalysis
        }

        let aggregated = aggregateChunkAnalytics(chunkAnalytics)
        let entryDate = parseEntryDate(entry: entry)

        // Create EntryAnalytics
        let entryAnalytics = EntryAnalytics(
            entryId: entry.id,
            date: entryDate,
            happinessScore: aggregated.happiness,
            valence: aggregated.valence,
            arousal: aggregated.arousal,
            emotions: aggregated.emotions,
            events: aggregated.events,
            confidence: aggregated.confidence
        )

        // Save to database
        try analyticsRepository.save(entryAnalytics)

        return entryAnalytics
    }

    // MARK: - Aggregation

    /// Aggregate multiple chunk analytics into a single entry analytics
    /// Uses trimmed mean to remove outliers and improve robustness
    private func aggregateChunkAnalytics(_ chunks: [ChunkAnalytics]) -> (
        happiness: Double,
        valence: Double,
        arousal: Double,
        emotions: EmotionScores,
        events: [DetectedEvent],
        confidence: Double
    ) {
        // Use trimmed mean (remove top and bottom 10%) for robustness
        let happiness = trimmedMean(chunks.map { $0.happiness })
        let valence = trimmedMean(chunks.map { $0.valence })
        let arousal = trimmedMean(chunks.map { $0.arousal })

        // Aggregate emotions
        let joy = trimmedMean(chunks.map { $0.joy })
        let sadness = trimmedMean(chunks.map { $0.sadness })
        let anger = trimmedMean(chunks.map { $0.anger })
        let anxiety = trimmedMean(chunks.map { $0.anxiety })
        let gratitude = trimmedMean(chunks.map { $0.gratitude })

        let emotions = EmotionScores(
            joy: joy,
            sadness: sadness,
            anger: anger,
            anxiety: anxiety,
            gratitude: gratitude
        )

        // Merge events from all chunks (deduplicate similar events)
        let events = mergeEvents(chunks.flatMap { $0.events })

        // Average confidence
        let confidence = chunks.map { $0.confidence }.reduce(0.0, +) / Double(chunks.count)

        return (happiness, valence, arousal, emotions, events, confidence)
    }

    /// Calculate trimmed mean (removes outliers)
    /// Removes top and bottom 10% before averaging
    private func trimmedMean(_ values: [Double]) -> Double {
        guard values.count > 2 else {
            return values.reduce(0.0, +) / Double(max(values.count, 1))
        }

        let sorted = values.sorted()
        let trimCount = Int(Double(values.count) * 0.1)

        let trimmed = sorted.dropFirst(trimCount).dropLast(trimCount)
        return trimmed.reduce(0.0, +) / Double(max(trimmed.count, 1))
    }

    /// Merge events from multiple chunks, removing near-duplicates
    private func mergeEvents(_ extractions: [EventExtraction]) -> [DetectedEvent] {
        var uniqueEvents: [DetectedEvent] = []
        var seenTitles: Set<String> = []

        for extraction in extractions {
            // Normalize title for comparison
            let normalizedTitle = extraction.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip if we've seen a very similar event
            if seenTitles.contains(normalizedTitle) {
                continue
            }

            seenTitles.insert(normalizedTitle)

            // Convert string sentiment to numeric
            let sentimentValue: Double = {
                switch extraction.sentiment.lowercased() {
                case "positive": return 0.5
                case "negative": return -0.5
                default: return 0.0
                }
            }()

            let event = DetectedEvent(
                title: extraction.title,
                date: nil,
                description: extraction.description ?? "",
                sentiment: sentimentValue
            )

            uniqueEvents.append(event)
        }

        return uniqueEvents
    }

    /// Parse Date object from HumanEntry
    private func parseEntryDate(entry: HumanEntry) -> Date {
        // Filename format: [UUID]-[yyyy-MM-dd-HH-mm-ss].md
        let filename = entry.filename

        if let startBracket = filename.lastIndex(of: "["),
           let endBracket = filename.lastIndex(of: "]") {
            let dateRange = filename.index(after: startBracket)..<endBracket
            let dateString = String(filename[dateRange])

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"

            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return Date()
    }
}

// MARK: - Errors

enum AnalyticsError: Error, LocalizedError {
    case noChunksToAnalyze
    case allChunksFailedAnalysis

    var errorDescription: String? {
        switch self {
        case .noChunksToAnalyze:
            return "No chunks provided for analysis"
        case .allChunksFailedAnalysis:
            return "All chunks failed analysis"
        }
    }
}
