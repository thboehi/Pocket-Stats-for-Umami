import Foundation

/// Everything a widget, the control or a Shortcuts answer shows for one website.
struct WebsiteSnapshot: Hashable, Sendable, Identifiable {
    let accountID: UUID
    let websiteID: String
    let name: String
    let domain: String?
    let period: WidgetPeriod
    let stats: WebsiteStats
    let activeVisitors: Int?
    /// Visitors per bucket, with empty buckets filled in.
    let visitors: [TimeSeriesPoint]
    /// Average visitors per bucket over the previous period: the dashed line.
    let baseline: Double?
    /// X range of the chart. Today spans the whole day, so the line stops at
    /// the current hour, like an intraday stock chart.
    let chartDomain: ClosedRange<Date>
    var topPages: [MetricItem] = []

    var id: String { "\(accountID.uuidString)|\(websiteID)" }

    var change: Double? {
        Format.change(stats.current.visitors, from: stats.previous?.visitors)
    }

    var deepLink: DeepLink {
        .website(accountID: accountID, websiteID: websiteID)
    }

    // MARK: Loading

    static func load(account: Account, website: Website, period: WidgetPeriod,
                     includeActive: Bool = true, includeTopPages: Bool = false) async throws -> WebsiteSnapshot {
        let service = AnalyticsServiceFactory.make(for: account)
        let interval = period.preset.interval()
        let previousInterval = DateInterval(start: interval.start.addingTimeInterval(-interval.duration), duration: interval.duration)
        let unit = period.unit
        let websiteID = website.id

        async let stats = service.stats(websiteID: websiteID, interval: interval)
        async let traffic = service.traffic(websiteID: websiteID, interval: interval, unit: unit)
        async let previousTraffic = service.traffic(websiteID: websiteID, interval: previousInterval, unit: unit)
        async let active: Int? = includeActive ? try? service.activeVisitors(websiteID: websiteID) : nil
        async let pages: [MetricItem] = includeTopPages
            ? (try? service.metrics(websiteID: websiteID, type: .path, interval: interval, limit: 4)) ?? []
            : []

        let series = ((try? await traffic) ?? .empty).filled(in: interval, unit: unit).visitors
        let previous = (try? await previousTraffic)?.filled(in: previousInterval, unit: unit).visitors ?? []
        let baseline = previous.isEmpty ? nil : previous.map(\.value).reduce(0, +) / Double(previous.count)

        return try await WebsiteSnapshot(
            accountID: account.id,
            websiteID: websiteID,
            name: website.name,
            domain: website.domain,
            period: period,
            stats: stats,
            activeVisitors: active,
            visitors: series,
            baseline: baseline,
            chartDomain: chartDomain(for: period, interval: interval),
            topPages: pages
        )
    }

    static func chartDomain(for period: WidgetPeriod, interval: DateInterval, calendar: Calendar = .current) -> ClosedRange<Date> {
        guard period == .today,
              let end = calendar.date(byAdding: .day, value: 1, to: interval.start) else {
            return interval.start...interval.end
        }
        return interval.start...end.addingTimeInterval(-3_600)
    }

    // MARK: Samples (widget gallery, previews)

    static func sample(name: String = "Alpine Trails Blog", domain: String = "alpinetrails.example",
                       visitors: Double = 1_132, previous: Double = 1_021, active: Int = 14,
                       shape: [Double] = [3, 2, 1, 1, 2, 5, 12, 26, 38, 44, 52, 61, 58, 66, 71, 64, 55]) -> WebsiteSnapshot {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let series = shape.enumerated().map { index, value in
            TimeSeriesPoint(date: calendar.date(byAdding: .hour, value: index, to: start)!, value: value)
        }
        return WebsiteSnapshot(
            accountID: UUID(),
            websiteID: name,
            name: name,
            domain: domain,
            period: .today,
            stats: WebsiteStats(
                current: .init(pageviews: visitors * 2.5, visitors: visitors, visits: visitors * 1.24, bounces: visitors * 0.5, totaltime: visitors * 124),
                previous: .init(pageviews: previous * 2.4, visitors: previous, visits: previous * 1.27, bounces: previous * 0.53, totaltime: previous * 127)
            ),
            activeVisitors: active,
            visitors: series,
            baseline: shape.reduce(0, +) / Double(shape.count) * previous / max(visitors, 1),
            chartDomain: start...calendar.date(byAdding: .hour, value: 23, to: start)!,
            topPages: [
                MetricItem(value: "/", count: visitors * 0.9),
                MetricItem(value: "/trails/lac-bleu", count: visitors * 0.42),
                MetricItem(value: "/blog/winter-gear", count: visitors * 0.31),
                MetricItem(value: "/about", count: visitors * 0.12),
            ]
        )
    }

    static let samples: [WebsiteSnapshot] = [
        .sample(),
        .sample(name: "Swiss Watch Shop", domain: "shop.swisswatch.example", visitors: 2_111, previous: 2_390, active: 23,
                shape: [8, 5, 3, 2, 4, 9, 22, 48, 71, 80, 77, 90, 96, 88, 79, 72, 70]),
        .sample(name: "Boulangerie du Lac", domain: "boulangerie-du-lac.example", visitors: 115, previous: 98, active: 2,
                shape: [0, 0, 0, 0, 1, 4, 9, 11, 7, 5, 6, 8, 6, 4, 3, 5, 4]),
        .sample(name: "Portfolio", domain: "jane-design.example", visitors: 30, previous: 41, active: 0,
                shape: [1, 0, 0, 0, 0, 0, 1, 2, 3, 2, 1, 2, 3, 2, 1, 1, 2]),
        .sample(name: "Docs", domain: "docs.example", visitors: 842, previous: 790, active: 9,
                shape: [10, 6, 4, 3, 4, 8, 20, 35, 44, 50, 48, 52, 49, 51, 47, 40, 38]),
        .sample(name: "Newsletter", domain: "news.example", visitors: 356, previous: 356, active: 1,
                shape: [2, 1, 1, 1, 2, 4, 10, 18, 22, 25, 21, 20, 19, 22, 20, 18, 17]),
        .sample(name: "Status page", domain: "status.example", visitors: 64, previous: 80, active: 0,
                shape: [2, 2, 1, 1, 2, 2, 3, 4, 5, 4, 4, 3, 5, 4, 3, 3, 4]),
    ]
}
