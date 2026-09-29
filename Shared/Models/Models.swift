import Foundation

// MARK: - Websites

struct Website: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var domain: String?
    var shareId: String?
    var teamId: String?
    var userId: String?
    var createdAt: Date?
    var team: TeamSummary?
}

struct TeamSummary: Codable, Hashable, Sendable {
    let id: String
    let name: String
}

/// Paginated list envelope returned by Umami (`{ data, count, page, pageSize }`).
struct PagedResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    let data: [Item]
    let count: Int?
    let page: Int?
    let pageSize: Int?
}

struct UmamiUser: Codable, Hashable, Sendable {
    let id: String
    let username: String
    var role: String?
    var isAdmin: Bool?

    var hasAdminRights: Bool { isAdmin == true || role == "admin" }
}

struct LoginResponse: Decodable, Sendable {
    let token: String
    let user: UmamiUser
}

/// `GET /api/share/<id>`: the shared website and a token to read its stats.
struct ShareResponse: Decodable, Sendable {
    let websiteId: String
    let token: String
}

// MARK: - Stats

/// Summary stats for a period. Parsed by hand in `WebsiteStats.parse` because
/// Umami v2 (`{ value, prev }` objects) and v3 (flat numbers + `comparison`) differ.
struct WebsiteStats: Hashable, Sendable {
    struct Values: Hashable, Sendable {
        var pageviews: Double = 0
        var visitors: Double = 0
        var visits: Double = 0
        var bounces: Double = 0
        var totaltime: Double = 0

        /// Share of visits that viewed a single page (0...1).
        var bounceRate: Double { visits > 0 ? min(bounces / visits, 1) : 0 }
        /// Average visit duration in seconds.
        var averageVisitDuration: Double { visits > 0 ? totaltime / visits : 0 }
    }

    var current: Values
    var previous: Values?

    static let keys = ["pageviews", "visitors", "visits", "bounces", "totaltime"]

    static func parse(_ data: Data) throws -> WebsiteStats {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UmamiError.decoding("stats")
        }
        var current = Values()
        var previous = Values()
        var hasPrevious = false

        for key in keys {
            let raw = object[key]
            if let pair = raw as? [String: Any] {
                current[key] = JSONNumber.double(pair["value"]) ?? 0
                if let prev = JSONNumber.double(pair["prev"]) {
                    previous[key] = prev
                    hasPrevious = true
                }
            } else {
                current[key] = JSONNumber.double(raw) ?? 0
            }
        }
        if let comparison = object["comparison"] as? [String: Any] {
            hasPrevious = true
            for key in keys {
                previous[key] = JSONNumber.double(comparison[key]) ?? 0
            }
        }
        return WebsiteStats(current: current, previous: hasPrevious ? previous : nil)
    }
}

extension WebsiteStats.Values {
    subscript(key: String) -> Double {
        get {
            switch key {
            case "pageviews": pageviews
            case "visitors": visitors
            case "visits": visits
            case "bounces": bounces
            case "totaltime": totaltime
            default: 0
            }
        }
        set {
            switch key {
            case "pageviews": pageviews = newValue
            case "visitors": visitors = newValue
            case "visits": visits = newValue
            case "bounces": bounces = newValue
            case "totaltime": totaltime = newValue
            default: break
            }
        }
    }
}

enum JSONNumber {
    /// Umami sometimes serialises big integers as strings (`"pageviews": "37"`).
    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: number.doubleValue
        case let string as String: Double(string)
        default: nil
        }
    }
}

// MARK: - Time series

struct TimeSeriesPoint: Hashable, Sendable, Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct TrafficSeries: Hashable, Sendable {
    var pageviews: [TimeSeriesPoint]
    var visitors: [TimeSeriesPoint]

    static let empty = TrafficSeries(pageviews: [], visitors: [])

    /// Parses `{ pageviews: [{x, y}], sessions: [{x, y}] }`. `x` is either
    /// `"yyyy-MM-dd HH:mm:ss"` in the requested time zone (v3) or ISO 8601 (v2).
    static func parse(_ data: Data, timeZone: TimeZone) throws -> TrafficSeries {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UmamiError.decoding("pageviews")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        func points(_ key: String) -> [TimeSeriesPoint] {
            guard let items = object[key] as? [[String: Any]] else { return [] }
            return items.compactMap { item in
                guard let x = item["x"] as? String, let y = JSONNumber.double(item["y"]) else { return nil }
                guard let date = formatter.date(from: x) ?? UmamiDate.parse(x) else { return nil }
                return TimeSeriesPoint(date: date, value: y)
            }
            .sorted { $0.date < $1.date }
        }
        return TrafficSeries(pageviews: points("pageviews"), visitors: points("sessions"))
    }
}

// MARK: - Metrics

struct MetricItem: Hashable, Sendable, Identifiable {
    let value: String?
    let count: Double
    /// Only set for `city` metrics.
    var country: String? = nil
    var id: String { "\(value ?? "∅")|\(country ?? "")" }

    static func parse(_ data: Data) throws -> [MetricItem] {
        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw UmamiError.decoding("metrics")
        }
        return items.map { item in
            let value: String? = switch item["x"] {
            case let string as String: string
            case let number as NSNumber: number.stringValue
            default: nil
            }
            return MetricItem(value: value, count: JSONNumber.double(item["y"]) ?? 0, country: item["country"] as? String)
        }
    }
}

enum MetricType: String, CaseIterable, Identifiable, Hashable, Sendable {
    case path, title, entry, exit, referrer, browser, os, device, country, city, language, screen, event

    var id: String { rawValue }

    /// Umami v2 used `url` for what v3 calls `path`.
    var legacyName: String? { self == .path ? "url" : nil }
}

enum UmamiDate {
    static func parse(_ string: String) -> Date? {
        if let date = try? Date(string, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true).timeZone(separator: .omitted)) {
            return date
        }
        if let date = try? Date(string, strategy: .iso8601) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}

extension TrafficSeries {
    /// Umami only returns the buckets that have data: adds the empty ones, from
    /// the start of `interval` to its end, so lines and comparisons line up.
    func filled(in interval: DateInterval, unit: TimeUnit, calendar: Calendar = .current) -> TrafficSeries {
        let component = unit.calendarComponent
        guard var cursor = calendar.dateInterval(of: component, for: interval.start)?.start else { return self }
        var buckets: [Date] = []
        while cursor < interval.end, buckets.count < 2_000 {
            buckets.append(cursor)
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else { break }
            cursor = next
        }
        func fill(_ points: [TimeSeriesPoint]) -> [TimeSeriesPoint] {
            var values: [Date: Double] = [:]
            for point in points {
                values[calendar.dateInterval(of: component, for: point.date)?.start ?? point.date, default: 0] += point.value
            }
            return buckets.map { TimeSeriesPoint(date: $0, value: values[$0] ?? 0) }
        }
        return TrafficSeries(pageviews: fill(pageviews), visitors: fill(visitors))
    }
}
