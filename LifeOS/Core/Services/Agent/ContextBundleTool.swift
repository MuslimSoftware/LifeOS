import Foundation

/// Tool for loading a comprehensive context bundle at conversation start
/// Provides recent analytics, themes, saved memories, and summaries in one call
class ContextBundleTool: AgentTool {
    let name = "context_bundle"
    let description = "Load a comprehensive context bundle with recent analytics, themes, saved memories, and summaries. Call this at the start of a conversation for warm-start context."

    private let analyticsRepository: EntryAnalyticsRepository
    private let monthSummaryRepository: MonthSummaryRepository
    private let memoryRepository: AgentMemoryRepository
    private let calculator: HappinessIndexCalculator

    init(
        analyticsRepository: EntryAnalyticsRepository,
        monthSummaryRepository: MonthSummaryRepository,
        memoryRepository: AgentMemoryRepository,
        calculator: HappinessIndexCalculator
    ) {
        self.analyticsRepository = analyticsRepository
        self.monthSummaryRepository = monthSummaryRepository
        self.memoryRepository = memoryRepository
        self.calculator = calculator
    }

    var parametersSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "recentDays": [
                    "type": "integer",
                    "default": 60,
                    "description": "Number of recent days to include in analytics"
                ],
                "historyMonths": [
                    "type": "integer",
                    "default": 24,
                    "description": "Number of months of summaries to include"
                ],
                "includeMemory": [
                    "type": "boolean",
                    "default": true,
                    "description": "Include saved insights and rules from memory"
                ]
            ]
        ]
    }

    func execute(arguments: [String: Any]) async throws -> Any {
        let recentDays = arguments["recentDays"] as? Int ?? 60
        let historyMonths = arguments["historyMonths"] as? Int ?? 24
        let includeMemory = arguments["includeMemory"] as? Bool ?? true

        let calendar = Calendar.current
        let toDate = Date()
        guard let fromDate = calendar.date(byAdding: .day, value: -recentDays, to: toDate) else {
            throw ToolError.executionFailed("Invalid date range")
        }

        // 1. Get recent analytics
        let recentAnalytics = try analyticsRepository.getAnalytics(from: fromDate, to: toDate)

        // 2. Compute mood metrics
        let moodMetrics = computeMoodMetrics(analytics: recentAnalytics)

        // 3. Get month summaries
        let summaries = try getRecentSummaries(months: historyMonths)

        // 4. Get saved memories (if requested)
        var memories: [[String: Any]] = []
        if includeMemory {
            let savedMemories = try memoryRepository.getRecent(limit: 20)
            memories = savedMemories.map { $0.toJSON() }

            // Update access times
            for memory in savedMemories {
                try? memoryRepository.updateAccessTime(memory.id)
            }
        }

        // 5. Build context bundle
        let bundle: [String: Any] = [
            "recentTimeline": [
                "days": recentDays,
                "dateRange": [
                    ISO8601DateFormatter().string(from: fromDate),
                    ISO8601DateFormatter().string(from: toDate)
                ],
                "analytics": moodMetrics,
                "entryCount": recentAnalytics.count
            ],
            "historicalSummaries": summaries,
            "savedMemories": memories,
            "metadata": [
                "totalAnalytics": recentAnalytics.count,
                "totalSummaries": summaries.count,
                "totalMemories": memories.count,
                "loadedAt": ISO8601DateFormatter().string(from: Date())
            ]
        ]

        return bundle
    }

    // MARK: - Private Helpers

    private func computeMoodMetrics(analytics: [EntryAnalytics]) -> [String: Any] {
        guard !analytics.isEmpty else {
            return [
                "happiness": ["avg": 0, "trend": "unknown"],
                "stress": ["avg": 0, "trend": "unknown"],
                "energy": ["avg": 0, "trend": "unknown"]
            ]
        }

        // Calculate averages
        let happinessAvg = analytics.map { $0.happinessScore }.reduce(0, +) / Double(analytics.count)

        // Calculate stress (inverse of happiness, simplified)
        let valenceAvg = analytics.map { $0.valence }.reduce(0, +) / Double(analytics.count)
        let arousalAvg = analytics.map { $0.arousal }.reduce(0, +) / Double(analytics.count)

        // Stress approximation: high arousal + low valence
        let stressAvg = (arousalAvg * 50) + ((1 - valenceAvg) * 50)

        // Energy approximation: arousal level
        let energyAvg = arousalAvg * 100

        // Calculate trends (last 7 days vs previous 7 days)
        let trends = calculateTrends(analytics: analytics)

        return [
            "happiness": [
                "avg": round(happinessAvg * 10) / 10,
                "trend": trends.happiness
            ],
            "stress": [
                "avg": round(stressAvg * 10) / 10,
                "trend": trends.stress
            ],
            "energy": [
                "avg": round(energyAvg * 10) / 10,
                "trend": trends.energy
            ]
        ]
    }

    private func calculateTrends(analytics: [EntryAnalytics]) -> (happiness: String, stress: String, energy: String) {
        guard analytics.count >= 14 else {
            return ("stable", "stable", "stable")
        }

        // Sort by date
        let sorted = analytics.sorted { $0.date < $1.date }

        // Split into recent 7 days and previous 7 days
        let midpoint = sorted.count / 2
        let older = sorted[..<midpoint]
        let newer = sorted[midpoint...]

        // Calculate averages
        let olderHappiness = older.map { $0.happinessScore }.reduce(0, +) / Double(older.count)
        let newerHappiness = newer.map { $0.happinessScore }.reduce(0, +) / Double(newer.count)

        let olderStress = older.map { (($0.arousal * 50) + ((1 - $0.valence) * 50)) }.reduce(0, +) / Double(older.count)
        let newerStress = newer.map { (($0.arousal * 50) + ((1 - $0.valence) * 50)) }.reduce(0, +) / Double(newer.count)

        let olderEnergy = older.map { $0.arousal * 100 }.reduce(0, +) / Double(older.count)
        let newerEnergy = newer.map { $0.arousal * 100 }.reduce(0, +) / Double(newer.count)

        // Determine trends
        let happinessTrend = determineTrend(older: olderHappiness, newer: newerHappiness)
        let stressTrend = determineTrend(older: olderStress, newer: newerStress)
        let energyTrend = determineTrend(older: olderEnergy, newer: newerEnergy)

        return (happinessTrend, stressTrend, energyTrend)
    }

    private func determineTrend(older: Double, newer: Double) -> String {
        let change = newer - older
        let threshold = 5.0 // 5% change threshold

        if change > threshold {
            return "increasing"
        } else if change < -threshold {
            return "decreasing"
        } else {
            return "stable"
        }
    }

    private func getRecentSummaries(months: Int) throws -> [[String: Any]] {
        let calendar = Calendar.current
        let now = Date()

        var summaries: [[String: Any]] = []

        for monthOffset in 0..<months {
            guard let targetDate = calendar.date(byAdding: .month, value: -monthOffset, to: now) else {
                continue
            }

            let components = calendar.dateComponents([.year, .month], from: targetDate)
            guard let year = components.year, let month = components.month else {
                continue
            }

            // Try to get summary for this month
            if let summary = try monthSummaryRepository.get(year: year, month: month) {
                summaries.append([
                    "month": "\(year)-\(String(format: "%02d", month))",
                    "happiness": summary.happinessAvg,
                    "narrative": summary.summaryText.prefix(200) + "..." // Truncate for context
                ])
            }
        }

        return summaries
    }
}
