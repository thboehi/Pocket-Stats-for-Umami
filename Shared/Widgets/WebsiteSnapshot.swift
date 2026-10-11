import Foundation

/// Everything a widget, the control or a Shortcuts answer shows for one website.
struct WebsiteSnapshot: Hashable, Sendable, Identifiable {
    let accountID: UUID
    let websiteID: String
    let name: String
    let domain: String?
    let period: WidgetPeriod
    /// The figure put forward, chosen when configuring the widget.
    var metric: WidgetMetric
    let stats: WebsiteStats
    let activeVisitors: Int?
    /// The charted series, with empty buckets filled in. It follows `metric`,
    /// except for the metrics Umami has no series for (see `chartedMetric`).
    var series: [TimeSeriesPoint]
    /// Average per bucket over the previous period: the dashed line. `nil` when
    /// the comparison is off or there is nothing to compare with.
    var baseline: Double?
    /// X range of the chart. Today spans the whole day, so the line stops at
    /// the current hour, like an intraday stock chart.
    let chartDomain: ClosedRange<Date>
    /// The configured list at the bottom of the large widget, if any.
    var breakdownType: MetricType? = nil
    var breakdown: [MetricItem] = []
    /// `false` hides the change badge and the dashed line, and spares a request.
    var comparing = true

    var id: String { "\(accountID.uuidString)|\(websiteID)" }

    /// The headline figure, and the string the widgets print for it.
    var value: Double { metric.value(stats.current) }
    var headline: String { metric.format(value) }

    var change: Double? {
        guard comparing, let previous = stats.previous else { return nil }
        return Format.change(value, from: metric.value(previous))
    }

    var deepLink: DeepLink {
        .website(accountID: accountID, websiteID: websiteID)
    }

    // MARK: Loading

    /// A widget refresh runs on a time budget, so a snapshot asks for the least
    /// it can: the stats call, which already carries the previous period, plus
    /// the curve when something draws one, plus whatever the family adds.
    static func load(account: Account, website: Website, period: WidgetPeriod,
                     metric: WidgetMetric = .visitors, comparing: Bool = true,
                     breakdown: MetricType? = nil, includeActive: Bool = true,
                     includeSeries: Bool = true) async throws -> WebsiteSnapshot {
        let service = AnalyticsServiceFactory.make(for: account)
        let interval = period.preset.interval()
        let unit = period.unit
        let websiteID = website.id

        async let stats = service.stats(websiteID: websiteID, interval: interval)
        async let traffic: TrafficSeries? = includeSeries
            ? try? service.traffic(websiteID: websiteID, interval: interval, unit: unit)
            : nil
        async let active: Int? = includeActive ? try? service.activeVisitors(websiteID: websiteID) : nil
        async let items = breakdownItems(service: service, websiteID: websiteID, type: breakdown, interval: interval)

        let series = includeSeries ? metric.series(((await traffic) ?? .empty).filled(in: interval, unit: unit)) : []
        // The dashed line is the previous period's average per bucket. The
        // stats call already returns that period's totals, so dividing them by
        // the number of buckets spares a second traffic request per website.
        let loaded = try await stats
        let previousTotal = loaded.previous.map { metric.chartTotal($0) }
        let baseline = comparing && !series.isEmpty
            ? previousTotal.map { $0 / Double(series.count) }
            : nil

        return await WebsiteSnapshot(
            accountID: account.id,
            websiteID: websiteID,
            name: website.name,
            domain: website.domain,
            period: period,
            metric: metric,
            stats: loaded,
            activeVisitors: active,
            series: series,
            baseline: baseline,
            chartDomain: chartDomain(for: period, interval: interval),
            breakdownType: breakdown,
            breakdown: items,
            comparing: comparing
        )
    }

    private static func breakdownItems(service: any AnalyticsService, websiteID: String,
                                       type: MetricType?, interval: DateInterval) async -> [MetricItem] {
        guard let type else { return [] }
        return (try? await service.metrics(websiteID: websiteID, type: type, interval: interval, limit: 5)) ?? []
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
                       metric: WidgetMetric = .visitors, breakdownType: MetricType? = .path,
                       shape: [Double] = [3, 2, 1, 1, 2, 5, 12, 26, 38, 44, 52, 61, 58, 66, 71, 64, 55]) -> WebsiteSnapshot {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let scale = sampleScale(metric)
        let series = shape.enumerated().map { index, value in
            TimeSeriesPoint(date: calendar.date(byAdding: .hour, value: index, to: start)!, value: value * scale)
        }
        return WebsiteSnapshot(
            accountID: UUID(),
            websiteID: name,
            name: name,
            domain: domain,
            period: .today,
            metric: metric,
            stats: WebsiteStats(
                current: .init(pageviews: visitors * 2.5, visitors: visitors, visits: visitors * 1.24, bounces: visitors * 0.5, totaltime: visitors * 124),
                previous: .init(pageviews: previous * 2.4, visitors: previous, visits: previous * 1.27, bounces: previous * 0.53, totaltime: previous * 127)
            ),
            activeVisitors: active,
            series: series,
            baseline: shape.reduce(0, +) / Double(shape.count) * scale * previous / max(visitors, 1),
            chartDomain: start...calendar.date(byAdding: .hour, value: 23, to: start)!,
            breakdownType: breakdownType,
            breakdown: Self.sampleBreakdown(breakdownType, visitors: visitors)
        )
    }

    private static func sampleBreakdown(_ type: MetricType?, visitors: Double) -> [MetricItem] {
        guard let type else { return [] }
        let values: [String] = switch type {
        case .path: ["/", "/trails/lac-bleu", "/blog/winter-gear", "/about"]
        case .referrer: ["google.com", "news.ycombinator.com", "", "mastodon.social"]
        case .country: ["CH", "FR", "DE", "US"]
        case .browser: ["safari", "chrome", "firefox", "edge"]
        case .device: ["mobile", "desktop", "tablet", "laptop"]
        case .os: ["iOS", "macOS", "Windows", "Android"]
        case .event: ["signup", "download", "contact", "share"]
        default: []
        }
        let weights: [Double] = [0.9, 0.42, 0.31, 0.12]
        return zip(values, weights).map { value, weight in
            MetricItem(value: value, count: (visitors * weight).rounded())
        }
    }

    /// The same sample shown with another metric: the widget gallery previews a
    /// configuration before any real data exists.
    func previewed(as metric: WidgetMetric) -> WebsiteSnapshot {
        let ratio = Self.sampleScale(metric) / Self.sampleScale(self.metric)
        var copy = self
        copy.metric = metric
        copy.series = series.map { TimeSeriesPoint(date: $0.date, value: $0.value * ratio) }
        copy.baseline = baseline.map { $0 * ratio }
        return copy
    }

    private static func sampleScale(_ metric: WidgetMetric) -> Double {
        metric.chartedMetric == .pageviews ? 2.5 : 1
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
