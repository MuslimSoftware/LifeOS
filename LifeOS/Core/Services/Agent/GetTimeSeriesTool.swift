import Foundation

/// Tool for retrieving time series data for happiness, stress, or energy metrics
class GetTimeSeriesTool: AgentTool {
    private let calculator: HappinessIndexCalculator
    private let repository: EntryAnalyticsRepository

    let name = "get_time_series"
    let description = "Get time series data for happiness, stress, or energy over a date range. Use this when the user asks about trends, patterns, or how they've been feeling over time."

    let parametersSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "metric": [
                "type": "string",
                "enum": ["happiness", "stress", "energy"],
                "description": "The metric to retrieve: happiness (0-100), stress (0-100), or energy (0-100)"
            ],
            "fromDate": [
                "type": "string",
                "description": "Start date in ISO 8601 format (e.g., '2025-01-01')"
            ],
            "toDate": [
                "type": "string",
                "description": "End date in ISO 8601 format (e.g., '2025-12-31')"
            ]
        ],
        "required": ["metric", "fromDate", "toDate"]
    ]

    init(calculator: HappinessIndexCalculator, repository: EntryAnalyticsRepository) {
        self.calculator = calculator
        self.repository = repository
    }

    func execute(arguments: [String: Any]) async throws -> Any {
        // Extract arguments
        guard let metric = arguments["metric"] as? String else {
            throw ToolError.missingRequiredArgument("metric")
        }

        guard let fromDateString = arguments["fromDate"] as? String,
              let fromDate = ISO8601DateFormatter().date(from: fromDateString) else {
            throw ToolError.invalidDateFormat(arguments["fromDate"] as? String ?? "nil")
        }

        guard let toDateString = arguments["toDate"] as? String,
              let toDate = ISO8601DateFormatter().date(from: toDateString) else {
            throw ToolError.invalidDateFormat(arguments["toDate"] as? String ?? "nil")
        }

        // Validate metric
        guard ["happiness", "stress", "energy"].contains(metric) else {
            throw ToolError.invalidArgumentType("metric", expectedType: "one of: happiness, stress, energy")
        }

        // Get entries in date range
        let entries = try repository.getAnalytics(from: fromDate, to: toDate)

        // Compute the requested metric
        var dataPoints: [(date: Date, value: Double)]

        switch metric {
        case "happiness":
            dataPoints = entries.map { ($0.date, $0.happinessScore) }

        case "stress":
            dataPoints = entries.map { entry in
                let stress = calculator.computeStressScore(analytics: entry)
                return (entry.date, stress)
            }

        case "energy":
            dataPoints = entries.map { entry in
                let energy = calculator.computeEnergyScore(analytics: entry)
                return (entry.date, energy)
            }

        default:
            throw ToolError.invalidArgumentType("metric", expectedType: "one of: happiness, stress, energy")
        }

        // Calculate statistics
        let values = dataPoints.map { $0.value }
        let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0

        // Determine trend (compare first half vs second half)
        var trend = "stable"
        if dataPoints.count >= 4 {
            let midpoint = dataPoints.count / 2
            let firstHalf = dataPoints.prefix(midpoint).map { $0.value }
            let secondHalf = dataPoints.suffix(dataPoints.count - midpoint).map { $0.value }

            let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
            let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

            let change = secondAvg - firstAvg
            if change > 5 {
                trend = "increasing"
            } else if change < -5 {
                trend = "decreasing"
            }
        }

        // Format results
        let isoFormatter = ISO8601DateFormatter()
        let formattedDataPoints = dataPoints.map { point in
            [
                "date": isoFormatter.string(from: point.date),
                "value": round(point.value * 10) / 10
            ]
        }

        return [
            "metric": metric,
            "dataPoints": formattedDataPoints,
            "statistics": [
                "average": round(average * 10) / 10,
                "min": round(minValue * 10) / 10,
                "max": round(maxValue * 10) / 10,
                "count": dataPoints.count,
                "trend": trend
            ],
            "dateRange": [
                "from": fromDateString,
                "to": toDateString
            ]
        ]
    }
}
