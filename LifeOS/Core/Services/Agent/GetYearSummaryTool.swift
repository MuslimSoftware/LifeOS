import Foundation

/// Tool for retrieving AI-generated yearly summaries
class GetYearSummaryTool: AgentTool {
    private let repository: YearSummaryRepository

    let name = "get_year_summary"
    let description = "Get the year-in-review summary with major themes, top events, and annual happiness statistics."

    let parametersSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "year": [
                "type": "integer",
                "description": "Year (e.g., 2025)"
            ]
        ],
        "required": ["year"]
    ]

    init(repository: YearSummaryRepository) {
        self.repository = repository
    }

    func execute(arguments: [String: Any]) async throws -> Any {
        // Extract arguments
        guard let year = arguments["year"] as? Int else {
            throw ToolError.missingRequiredArgument("year")
        }

        // Retrieve summary from database
        guard let summary = try repository.get(year: year) else {
            return [
                "found": false,
                "message": "No summary found for year \(year). This year may not have been analyzed yet."
            ]
        }

        // Format the summary for the agent
        return [
            "found": true,
            "year": year,
            "summaryText": summary.summaryText,
            "happiness": [
                "average": round(summary.happinessAvg * 10) / 10,
                "confidenceInterval": [
                    "lower": round(summary.happinessCI.0 * 10) / 10,
                    "upper": round(summary.happinessCI.1 * 10) / 10
                ]
            ],
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
