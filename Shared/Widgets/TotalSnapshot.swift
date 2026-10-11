import Foundation

/// Several websites added up: one figure for everything you run.
struct TotalSnapshot: Hashable, Sendable {
    struct Site: Hashable, Sendable, Identifiable {
        let id: String
        let name: String
        let value: Double
    }

    let title: String
    let period: WidgetPeriod
    let metric: WidgetMetric
    let stats: WebsiteStats
    let series: [TimeSeriesPoint]
    let baseline: Double?
    let chartDomain: ClosedRange<Date>
    /// The websites behind the total, biggest first.
    let sites: [Site]
    var comparing = true

    var value: Double { metric.value(stats.current) }
    var headline: String { metric.format(value) }

    var change: Double? {
        guard comparing, let previous = stats.previous else { return nil }
        return Format.change(value, from: metric.value(previous))
    }

    // MARK: Loading

    /// Summing the raw counters and only then computing the ratios gives a
    /// properly weighted bounce rate and visit duration: a site with 10 visits
    /// never counts as much as one with 10 000.
    static func load(targets: [(Account, Website)], title: String, period: WidgetPeriod,
                     metric: WidgetMetric = .visitors, comparing: Bool = true,
                     includeSeries: Bool = true) async -> TotalSnapshot {
        let interval = period.preset.interval()

        let loaded = await withTaskGroup(of: (Int, WebsiteSnapshot?).self) { group in
            for (index, target) in targets.enumerated() {
                group.addTask {
                    (index, try? await WebsiteSnapshot.load(account: target.0, website: target.1, period: period,
                                                            metric: metric, comparing: comparing,
                                                            includeActive: false, includeSeries: includeSeries))
                }
            }
            var results: [(Int, WebsiteSnapshot)] = []
            for await (index, snapshot) in group {
                if let snapshot { results.append((index, snapshot)) }
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }

        var current = WebsiteStats.Values()
        var previous = WebsiteStats.Values()
        var hasPrevious = false
        var buckets: [Date: Double] = [:]
        for snapshot in loaded {
            current.add(snapshot.stats.current)
            if let values = snapshot.stats.previous {
                previous.add(values)
                hasPrevious = true
            }
            for point in snapshot.series {
                buckets[point.date, default: 0] += point.value
            }
        }

        let series = buckets.keys.sorted().map { TimeSeriesPoint(date: $0, value: buckets[$0] ?? 0) }
        let previousTotal = hasPrevious ? metric.chartTotal(previous) : nil
        return TotalSnapshot(
            title: title,
            period: period,
            metric: metric,
            stats: WebsiteStats(current: current, previous: hasPrevious ? previous : nil),
            series: series,
            baseline: comparing && !series.isEmpty ? previousTotal.map { $0 / Double(series.count) } : nil,
            chartDomain: WebsiteSnapshot.chartDomain(for: period, interval: interval),
            sites: loaded
                .map { Site(id: $0.id, name: $0.name, value: $0.value) }
                .sorted { $0.value > $1.value },
            comparing: comparing
        )
    }

    // MARK: Samples (widget gallery, previews)

    static func sample(metric: WidgetMetric = .visitors,
                       title: String = String(localized: "All websites")) -> TotalSnapshot {
        let snapshots = WebsiteSnapshot.samples.map { $0.previewed(as: metric) }
        var current = WebsiteStats.Values()
        var previous = WebsiteStats.Values()
        var buckets: [Date: Double] = [:]
        for snapshot in snapshots {
            current.add(snapshot.stats.current)
            if let values = snapshot.stats.previous { previous.add(values) }
            for point in snapshot.series { buckets[point.date, default: 0] += point.value }
        }
        let series = buckets.keys.sorted().map { TimeSeriesPoint(date: $0, value: buckets[$0] ?? 0) }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        return TotalSnapshot(
            title: title,
            period: .today,
            metric: metric,
            stats: WebsiteStats(current: current, previous: previous),
            series: series,
            // The sample curves are shapes, not real traffic: scale the mean
            // the way the single-website samples do, or the dashed line lands
            // somewhere the curve never goes.
            baseline: series.isEmpty ? nil : series.map(\.value).reduce(0, +) / Double(series.count)
                * (metric.chartTotal(previous) / max(metric.chartTotal(current), 1)),
            chartDomain: start...calendar.date(byAdding: .hour, value: 23, to: start)!,
            sites: snapshots.map { Site(id: $0.id, name: $0.name, value: $0.value) }.sorted { $0.value > $1.value }
        )
    }
}

extension WebsiteStats.Values {
    mutating func add(_ other: WebsiteStats.Values) {
        pageviews += other.pageviews
        visitors += other.visitors
        visits += other.visits
        bounces += other.bounces
        totaltime += other.totaltime
    }
}
