import Foundation

/// Service for generating hierarchical summaries (monthly and yearly)
/// Uses OpenAI to create narrative summaries from analytics data
class SummarizationService {

    private let openAIService: OpenAIService
    private let analyticsRepository: EntryAnalyticsRepository
    private let monthSummaryRepository: MonthSummaryRepository
    private let yearSummaryRepository: YearSummaryRepository
    private let happinessCalculator: HappinessIndexCalculator

    init(
        openAIService: OpenAIService = OpenAIService(),
        analyticsRepository: EntryAnalyticsRepository,
        monthSummaryRepository: MonthSummaryRepository,
        yearSummaryRepository: YearSummaryRepository,
        happinessCalculator: HappinessIndexCalculator = HappinessIndexCalculator()
    ) {
        self.openAIService = openAIService
        self.analyticsRepository = analyticsRepository
        self.monthSummaryRepository = monthSummaryRepository
        self.yearSummaryRepository = yearSummaryRepository
        self.happinessCalculator = happinessCalculator
    }

    // MARK: - Month Summary

    func summarizeMonth(year: Int, month: Int) async throws -> MonthSummary {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let analytics = try analyticsRepository.getAnalytics(from: startOfMonth, to: endOfMonth)

        guard !analytics.isEmpty else {
            throw SummarizationError.noDataForPeriod
        }

        let (happinessAvg, happinessCI) = happinessCalculator.computeMonthlyAggregates(entries: analytics)
        let allEvents = analytics.flatMap { $0.events }
        let topEvents = selectTopEvents(from: allEvents, limit: 10)

        let (summaryText, driversPositive, driversNegative) = try await generateMonthNarrative(
            year: year,
            month: month,
            analytics: analytics,
            topEvents: topEvents
        )

        let sourceSpans = analytics.map { entry in
            SourceSpan(entryId: entry.entryId, startChar: 0, endChar: 0)
        }

        let summary = MonthSummary(
            year: year,
            month: month,
            summaryText: summaryText,
            happinessAvg: happinessAvg,
            happinessConfidenceInterval: happinessCI,
            driversPositive: driversPositive,
            driversNegative: driversNegative,
            topEvents: topEvents,
            sourceSpans: sourceSpans
        )

        try monthSummaryRepository.save(summary)

        return summary
    }

    private func generateMonthNarrative(
        year: Int,
        month: Int,
        analytics: [EntryAnalytics],
        topEvents: [DetectedEvent]
    ) async throws -> (summary: String, positive: [String], negative: [String]) {
        let monthName = DateFormatter().monthSymbols[month - 1]
        let avgEmotions = aggregateEmotions(analytics.map { $0.emotions })
        let eventsText = topEvents.map { "- \($0.title) (\($0.sentiment))" }.joined(separator: "\n")

        let prompt = """
        Generate a summary for \(monthName) \(year) based on journal analytics.

        **Statistics:**
        - Total entries: \(analytics.count)
        - Average happiness: \(String(format: "%.1f", analytics.map { $0.happinessScore }.reduce(0, +) / Double(analytics.count)))/100
        - Emotions: Joy \(String(format: "%.2f", avgEmotions.joy)), Sadness \(String(format: "%.2f", avgEmotions.sadness)), Anxiety \(String(format: "%.2f", avgEmotions.anxiety))

        **Key Events:**
        \(eventsText)

        Please provide:
        1. A 2-3 sentence narrative summary of the month
        2. 3-5 positive drivers (what went well)
        3. 3-5 negative drivers (what was challenging)

        Be specific and insightful. Focus on themes and patterns.
        """

        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": "You are a compassionate life coach analyzing journal data. Provide insightful, empathetic summaries."
            ],
            [
                "role": "user",
                "content": prompt
            ]
        ]

        // Define schema for structured output
        let schema: [String: Any] = [
            "name": "month_summary",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "summary": [
                        "type": "string",
                        "description": "2-3 sentence narrative summary"
                    ],
                    "positive_drivers": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "List of positive drivers (3-5 items)"
                    ],
                    "negative_drivers": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "List of negative drivers/challenges (3-5 items)"
                    ]
                ],
                "required": ["summary", "positive_drivers", "negative_drivers"],
                "additionalProperties": false
            ]
        ]

        // Call OpenAI
        let result: MonthNarrativeResponse = try await openAIService.chatCompletion(
            messages: messages,
            schema: schema,
            model: "gpt-4o-mini"
        )

        return (result.summary, result.positive_drivers, result.negative_drivers)
    }

    // MARK: - Year Summary

    /// Generate a summary for an entire year
    /// - Parameter year: The year to summarize
    /// - Returns: YearSummary with narrative and top events
    func summarizeYear(year: Int) async throws -> YearSummary {
        // Load all month summaries for the year
        let monthSummaries = try monthSummaryRepository.getAllForYear(year)

        guard !monthSummaries.isEmpty else {
            throw SummarizationError.noDataForPeriod
        }

        // Compute yearly happiness stats
        let allHappinessAvgs = monthSummaries.map { $0.happinessAvg }
        let yearlyAvg = allHappinessAvgs.reduce(0.0, +) / Double(allHappinessAvgs.count)

        // Compute confidence interval from monthly data
        let ci = computeConfidenceInterval(values: allHappinessAvgs)

        // Collect all events from all months
        let allEvents = monthSummaries.flatMap { $0.topEvents }
        let topEvents = selectTopEvents(from: allEvents, limit: 15)

        // Generate yearly narrative
        let summaryText = try await generateYearNarrative(
            year: year,
            monthSummaries: monthSummaries,
            topEvents: topEvents
        )

        // Collect source spans from all months
        let sourceSpans = monthSummaries.flatMap { $0.sourceSpans }

        let summary = YearSummary(
            year: year,
            summaryText: summaryText,
            happinessAvg: yearlyAvg,
            happinessConfidenceInterval: ci,
            topEvents: topEvents,
            sourceSpans: sourceSpans
        )

        // Save to database
        try yearSummaryRepository.save(summary)

        return summary
    }

    /// Generate narrative summary for a year using OpenAI
    private func generateYearNarrative(
        year: Int,
        monthSummaries: [MonthSummary],
        topEvents: [DetectedEvent]
    ) async throws -> String {
        // Build context from monthly summaries
        let monthTexts = monthSummaries.map { summary in
            let monthName = DateFormatter().monthSymbols[summary.month - 1]
            return "\(monthName): \(summary.summaryText)"
        }.joined(separator: "\n")

        let eventsText = topEvents.map { "- \($0.title) (\($0.sentiment))" }.joined(separator: "\n")

        let prompt = """
        Generate a comprehensive year-in-review for \(year).

        **Monthly Summaries:**
        \(monthTexts)

        **Top Events of the Year:**
        \(eventsText)

        Provide a 4-5 sentence narrative that:
        1. Captures the overall arc of the year
        2. Highlights major themes and turning points
        3. Acknowledges both growth and challenges
        4. Ends with a forward-looking reflection

        Be thoughtful, empathetic, and insightful.
        """

        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": "You are a compassionate life coach providing a year-end reflection. Be warm, insightful, and empowering."
            ],
            [
                "role": "user",
                "content": prompt
            ]
        ]

        let schema: [String: Any] = [
            "name": "year_summary",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "summary": [
                        "type": "string",
                        "description": "4-5 sentence year-in-review narrative"
                    ]
                ],
                "required": ["summary"],
                "additionalProperties": false
            ]
        ]

        let result: YearNarrativeResponse = try await openAIService.chatCompletion(
            messages: messages,
            schema: schema,
            model: "gpt-4o-mini"
        )

        return result.summary
    }

    // MARK: - Helper Methods

    /// Select top events by sentiment balance and uniqueness
    private func selectTopEvents(from events: [DetectedEvent], limit: Int) -> [DetectedEvent] {
        // Simple strategy: take top N unique events, balanced by sentiment
        var uniqueEvents: [DetectedEvent] = []
        var seenTitles: Set<String> = []

        for event in events {
            let normalized = event.title.lowercased()
            if !seenTitles.contains(normalized) {
                seenTitles.insert(normalized)
                uniqueEvents.append(event)
            }

            if uniqueEvents.count >= limit {
                break
            }
        }

        return uniqueEvents
    }

    /// Aggregate emotion scores across multiple analytics
    private func aggregateEmotions(_ emotions: [EmotionScores]) -> EmotionScores {
        guard !emotions.isEmpty else {
            return EmotionScores(joy: 0, sadness: 0, anger: 0, anxiety: 0, gratitude: 0)
        }

        let count = Double(emotions.count)
        return EmotionScores(
            joy: emotions.map { $0.joy }.reduce(0, +) / count,
            sadness: emotions.map { $0.sadness }.reduce(0, +) / count,
            anger: emotions.map { $0.anger }.reduce(0, +) / count,
            anxiety: emotions.map { $0.anxiety }.reduce(0, +) / count,
            gratitude: emotions.map { $0.gratitude }.reduce(0, +) / count
        )
    }

    /// Compute confidence interval
    private func computeConfidenceInterval(values: [Double]) -> (Double, Double) {
        guard values.count > 1 else {
            let value = values.first ?? 0.0
            return (value, value)
        }

        let mean = values.reduce(0.0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0.0, +) / Double(values.count - 1)
        let stdDev = sqrt(variance)
        let standardError = stdDev / sqrt(Double(values.count))
        let tValue: Double = values.count > 30 ? 1.96 : 2.0
        let margin = tValue * standardError

        return (mean - margin, mean + margin)
    }
}

// MARK: - Response Types

private struct MonthNarrativeResponse: Codable {
    let summary: String
    let positive_drivers: [String]
    let negative_drivers: [String]
}

private struct YearNarrativeResponse: Codable {
    let summary: String
}

// MARK: - Errors

enum SummarizationError: Error, LocalizedError {
    case noDataForPeriod

    var errorDescription: String? {
        switch self {
        case .noDataForPeriod:
            return "No analytics data available for this period"
        }
    }
}
