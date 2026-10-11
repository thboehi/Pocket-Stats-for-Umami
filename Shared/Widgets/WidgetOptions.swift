import AppIntents
import Foundation
import WidgetKit

// MARK: - Metric

/// The figure a widget puts forward. Chosen when configuring the widget.
enum WidgetMetric: String, AppEnum, CaseIterable {
    case visitors, pageviews, visits, bounceRate, visitDuration, viewsPerVisit

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Metric"
    static let caseDisplayRepresentations: [WidgetMetric: DisplayRepresentation] = [
        .visitors: "Visitors",
        .pageviews: "Views",
        .visits: "Visits",
        .bounceRate: "Bounce rate",
        .visitDuration: "Visit duration",
        .viewsPerVisit: "Views per visit",
    ]

    /// Compact name shown next to the period: "Bounce · 7d".
    var shortTitle: LocalizedStringResource {
        switch self {
        case .visitors: "Visitors"
        case .pageviews: "Views"
        case .visits: "Visits"
        case .bounceRate: "Bounce"
        case .visitDuration: "Duration"
        case .viewsPerVisit: "Views/visit"
        }
    }

    func value(_ values: WebsiteStats.Values) -> Double {
        switch self {
        case .visitors: values.visitors
        case .pageviews: values.pageviews
        case .visits: values.visits
        case .bounceRate: values.bounceRate
        case .visitDuration: values.averageVisitDuration
        case .viewsPerVisit: values.visits > 0 ? values.pageviews / values.visits : 0
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .bounceRate: Format.percent(value)
        case .visitDuration: Format.duration(value)
        case .viewsPerVisit: value.formatted(.number.precision(.fractionLength(1)))
        default: Format.number(value)
        }
    }

    /// A rise is good everywhere but on the bounce rate, where it is red.
    var higherIsBetter: Bool { self != .bounceRate }

    /// Umami returns two series only: pageviews and sessions. The bounce rate
    /// and the visit duration borrow the visits curve, which the chart labels.
    var chartedMetric: WidgetMetric {
        switch self {
        case .pageviews, .viewsPerVisit: .pageviews
        case .visitors: .visitors
        case .visits, .bounceRate, .visitDuration: .visits
        }
    }

    var chartsItself: Bool { chartedMetric == self }

    func series(_ traffic: TrafficSeries) -> [TimeSeriesPoint] {
        chartedMetric == .pageviews ? traffic.pageviews : traffic.visitors
    }

    /// Total of the charted series over a period. The stats call returns it, so
    /// the dashed line never costs a request of its own.
    func chartTotal(_ values: WebsiteStats.Values) -> Double {
        chartedMetric == .pageviews ? values.pageviews : values.visits
    }
}

// MARK: - Breakdown

/// The list at the bottom of the large website widget.
enum WidgetBreakdown: String, AppEnum, CaseIterable {
    case pages, referrers, countries, browsers, devices, operatingSystems, events, none

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Details"
    static let caseDisplayRepresentations: [WidgetBreakdown: DisplayRepresentation] = [
        .pages: "Top pages",
        .referrers: "Top referrers",
        .countries: "Top countries",
        .browsers: "Top browsers",
        .devices: "Top devices",
        .operatingSystems: "Top operating systems",
        .events: "Top events",
        .none: "None",
    ]

    var metricType: MetricType? {
        switch self {
        case .pages: .path
        case .referrers: .referrer
        case .countries: .country
        case .browsers: .browser
        case .devices: .device
        case .operatingSystems: .os
        case .events: .event
        case .none: nil
        }
    }
}

// MARK: - Watchlist

/// The order of the rows of the watchlist widget.
enum WatchlistSort: String, AppEnum, CaseIterable {
    case custom, metric, change, name

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Sort by"
    static let caseDisplayRepresentations: [WatchlistSort: DisplayRepresentation] = [
        .custom: "As configured",
        .metric: "Highest first",
        .change: "Biggest change",
        .name: "Name",
    ]

    func sorted(_ snapshots: [WebsiteSnapshot]) -> [WebsiteSnapshot] {
        switch self {
        case .custom:
            snapshots
        case .metric:
            snapshots.sorted { $0.value > $1.value }
        case .change:
            // Biggest move first, whichever way it went; sites without a
            // comparison go last.
            snapshots.sorted { abs($0.change ?? -1) > abs($1.change ?? -1) }
        case .name:
            snapshots.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}

/// How many websites the watchlist widget lists. Always clamped to what the
/// widget family can show without crushing the rows.
enum WatchlistRows: String, AppEnum, CaseIterable {
    case automatic, two, three, four, five, six, seven, eight

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Rows"
    static let caseDisplayRepresentations: [WatchlistRows: DisplayRepresentation] = [
        .automatic: "Automatic",
        .two: "2",
        .three: "3",
        .four: "4",
        .five: "5",
        .six: "6",
        .seven: "7",
        .eight: "8",
    ]

    private var requested: Int? {
        switch self {
        case .automatic: nil
        case .two: 2
        case .three: 3
        case .four: 4
        case .five: 5
        case .six: 6
        case .seven: 7
        case .eight: 8
        }
    }

    // The small, medium and large families only exist where there is a Home
    // Screen: `WidgetFamily.systemSmall` is unavailable on watchOS.
#if os(iOS)
    static func limit(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: 3
        case .systemLarge: 8
        default: 4
        }
    }

    static func automatic(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: 2
        case .systemLarge: 7
        default: 3
        }
    }

    func resolved(for family: WidgetFamily) -> Int {
        guard let requested else { return Self.automatic(for: family) }
        return min(requested, Self.limit(for: family))
    }
#endif
}
