import Foundation

/// Represents a query to the retrieve tool
/// Supports filtering, sorting, and different output views
struct RetrieveQuery {
    let scope: Scope
    let filter: Filter?
    let sort: Sort
    let limit: Int
    let view: View

    enum Scope: String, Codable {
        case entries
        case chunks
    }

    enum Sort: String, Codable {
        case dateDesc = "date_desc"
        case dateAsc = "date_asc"
        case similarityDesc = "similarity_desc"
        case magnitudeDesc = "magnitude_desc"
        case hybrid

        var isRecencyBased: Bool {
            self == .dateDesc || self == .dateAsc
        }
    }

    enum View: String, Codable {
        case raw
        case timeline
        case stats
        case histogram
    }

    struct Filter: Codable {
        let dateFrom: Date?
        let dateTo: Date?
        let ids: [String]?
        let entities: [String]?
        let topics: [String]?
        let sentiment: Sentiment?
        let metric: Metric?
        let similarTo: String?
        let keyword: String?
        let minSimilarity: Double?
        let timeGranularity: TimeGranularity?
        let recencyHalfLife: Int?

        enum Sentiment: String, Codable {
            case positive
            case negative
            case neutral
        }

        enum Metric: String, Codable {
            case happiness
            case stress
            case energy
        }

        enum TimeGranularity: String, Codable {
            case day
            case week
            case month
            case year
        }

        init(
            dateFrom: Date? = nil,
            dateTo: Date? = nil,
            ids: [String]? = nil,
            entities: [String]? = nil,
            topics: [String]? = nil,
            sentiment: Sentiment? = nil,
            metric: Metric? = nil,
            similarTo: String? = nil,
            keyword: String? = nil,
            minSimilarity: Double? = nil,
            timeGranularity: TimeGranularity? = nil,
            recencyHalfLife: Int? = nil
        ) {
            self.dateFrom = dateFrom
            self.dateTo = dateTo
            self.ids = ids
            self.entities = entities
            self.topics = topics
            self.sentiment = sentiment
            self.metric = metric
            self.similarTo = similarTo
            self.keyword = keyword
            self.minSimilarity = minSimilarity
            self.timeGranularity = timeGranularity
            self.recencyHalfLife = recencyHalfLife
        }
    }

    init(
        scope: Scope,
        filter: Filter? = nil,
        sort: Sort = .hybrid,
        limit: Int = 10,
        view: View = .raw
    ) {
        self.scope = scope
        self.filter = filter
        self.sort = sort
        self.limit = min(limit, 200) // Cap at 200
        self.view = view
    }

    /// Parse from tool arguments dictionary
    init(arguments: [String: Any]) throws {
        // Scope (required)
        guard let scopeString = arguments["scope"] as? String,
              let scope = Scope(rawValue: scopeString) else {
            throw RetrieveQueryError.invalidScope
        }
        self.scope = scope

        // Sort
        if let sortString = arguments["sort"] as? String,
           let sort = Sort(rawValue: sortString) {
            self.sort = sort
        } else {
            self.sort = .hybrid
        }

        // Limit
        self.limit = min((arguments["limit"] as? Int) ?? 10, 200)

        // View
        if let viewString = arguments["view"] as? String,
           let view = View(rawValue: viewString) {
            self.view = view
        } else {
            self.view = .raw
        }

        // Filter (optional)
        if let filterDict = arguments["filter"] as? [String: Any] {
            self.filter = try Filter(dictionary: filterDict)
        } else {
            self.filter = nil
        }
    }
}

// MARK: - Filter Parsing

extension RetrieveQuery.Filter {
    init(dictionary: [String: Any]) throws {
        // Dates
        let dateFormatter = ISO8601DateFormatter()
        var dateFrom: Date? = nil
        var dateTo: Date? = nil

        if let dateFromString = dictionary["dateFrom"] as? String {
            dateFrom = dateFormatter.date(from: dateFromString)
        }
        if let dateToString = dictionary["dateTo"] as? String {
            dateTo = dateFormatter.date(from: dateToString)
        }

        // Arrays
        let ids = dictionary["ids"] as? [String]
        let entities = dictionary["entities"] as? [String]
        let topics = dictionary["topics"] as? [String]

        // Enums
        var sentiment: Sentiment? = nil
        if let sentimentString = dictionary["sentiment"] as? String {
            sentiment = Sentiment(rawValue: sentimentString)
        }

        var metric: Metric? = nil
        if let metricString = dictionary["metric"] as? String {
            metric = Metric(rawValue: metricString)
        }

        var timeGranularity: TimeGranularity? = nil
        if let granularityString = dictionary["timeGranularity"] as? String {
            timeGranularity = TimeGranularity(rawValue: granularityString)
        }

        // Strings
        let similarTo = dictionary["similarTo"] as? String
        let keyword = dictionary["keyword"] as? String

        // Numbers
        let minSimilarity = dictionary["minSimilarity"] as? Double
        let recencyHalfLife = dictionary["recencyHalfLife"] as? Int

        self.init(
            dateFrom: dateFrom,
            dateTo: dateTo,
            ids: ids,
            entities: entities,
            topics: topics,
            sentiment: sentiment,
            metric: metric,
            similarTo: similarTo,
            keyword: keyword,
            minSimilarity: minSimilarity,
            timeGranularity: timeGranularity,
            recencyHalfLife: recencyHalfLife
        )
    }
}

// MARK: - Errors

enum RetrieveQueryError: Error, LocalizedError {
    case invalidScope
    case invalidFilter
    case missingRequiredFilter(String)

    var errorDescription: String? {
        switch self {
        case .invalidScope:
            return "Invalid scope. Must be one of: entries, chunks"
        case .invalidFilter:
            return "Invalid filter parameters"
        case .missingRequiredFilter(let filter):
            return "Missing required filter: \(filter)"
        }
    }
}
