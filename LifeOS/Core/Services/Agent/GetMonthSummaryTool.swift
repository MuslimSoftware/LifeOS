import Foundation

/// Tool for retrieving AI-generated monthly summaries
class GetMonthSummaryTool: AgentTool {
    private let repository: MonthSummaryRepository

    let name = "get_month_summary"
    let description = "Get the AI-generated summary for a specific month including narrative, what went well/poorly, top events, and happiness statistics."

    let parametersSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "year": [
                "type": "integer",
                "description": "Year (e.g., 2025)"
            ],
            "month": [
                "type": "integer",
                "description": "Month (1-12)",
                "minimum": 1,
                "maximum": 12
            ]
        ],
        "required": ["year", "month"]
    ]

    init(repository: MonthSummaryRepository) {
        self.repository = repository
    }

    func execute(arguments: [String: Any]) async throws -> Any {
        // Extract arguments
        guard let year = arguments["year"] as? Int else {
            throw ToolError.missingRequiredArgument("year")
        }

        guard let month = arguments["month"] as? Int else {
            throw ToolError.missingRequiredArgument("month")
        }

        // Validate month range
        guard month >= 1 && month <= 12 else {
            throw ToolError.invalidArgumentType("month", expectedType: "integer between 1 and 12")
        }

        // Retrieve summary from database
        guard let summary = try repository.get(year: year, month: month) else {
            return [
                "found": false,
                "message": "No summary found for \(year)-\(String(format: "%02d", month)). This month may not have been analyzed yet."
            ]
        }

        // Format the summary for the agent
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: year, month: month)) ?? Date()

        return [
            "found": true,
            "month": formatter.string(from: date),
            "summaryText": summary.summaryText,
            "happiness": [
                "average": round(summary.happinessAvg * 10) / 10,
                "confidenceInterval": [
                    "lower": round(summary.happinessCI.0 * 10) / 10,
                    "upper": round(summary.happinessCI.1 * 10) / 10
                ]
            ],
            "driversPositive": summary.driversPositive,
            "driversNegative": summary.driversNegative,
            "topEvents": summary.topEvents.map { event in
                let isoFormatter = ISO8601DateFormatter()
                return [
                    "title": event.title,
                    "date": isoFormatter.string(from: event.date),
                    "description": event.description ?? "",
                    "sentiment": event.sentiment
                ]
            }
        ]
    }
}
