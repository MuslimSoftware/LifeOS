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
        let lower = round(summary.happinessConfidenceInterval.lower * 10) / 10
        let upper = round(summary.happinessConfidenceInterval.upper * 10) / 10
        let avgHappiness = round(summary.happinessAvg * 10) / 10

        return [
            "found": true,
            "year": year,
            "summaryText": summary.summaryText,
            "happiness": [
                "average": avgHappiness,
                "confidenceInterval": [
                    "lower": lower,
                    "upper": upper
                ]
            ],
            "topEvents": summary.topEvents.map { event in
                let isoFormatter = ISO8601DateFormatter()
                let dateString = event.date != nil ? isoFormatter.string(from: event.date!) : ""
                return [
                    "title": event.title,
                    "date": dateString,
                    "description": event.description,
                    "sentiment": event.sentiment
                ]
            }
        ]
    }
}
