import Foundation
import Observation

/// Everything one website dashboard shows, for the selected period.
///
/// Requests run in tasks owned by this model, not by the list rows that
/// display them: SwiftUI cancels a row's `.task` when the row is recycled or
/// re-created, which used to leave sections stuck on their placeholders. All
/// sections are fetched together as soon as the dashboard opens, so they are
/// ready by the time they scroll into view.
///
/// The model also remembers every breakdown that was shown (the tab picked in
/// each section): a new period or a refresh reloads all of them, including
/// the sections scrolled out of view, which never get a chance to ask.
@MainActor
@Observable
final class DashboardModel {
    enum Metric {
        case loaded([MetricItem])
        case failed(String)
    }

    /// Rows shown per metric section before "Show all".
    static let previewCount = 6

    let website: Website
    private let service: CachingService

    private(set) var selection: DateSelection?
    /// The exact dates of the last load: every request of one load uses the
    /// same ones, even when a relative preset moves on in the meantime.
    private(set) var interval: DateInterval?
    private(set) var stats: WebsiteStats?
    private(set) var traffic: TrafficSeries?
    /// Same length just before the period, for the dashed comparison line.
    private(set) var previousTraffic: TrafficSeries?
    /// Buckets of `traffic`, which may still be the previous period's.
    private(set) var trafficUnit: TimeUnit?
    /// The figures on screen belong to the previous period and new ones are
    /// on their way: they stay visible, dimmed, then roll to the new values.
    private(set) var isShowingPreviousPeriod = false
    private(set) var errorMessage: String?
    private(set) var metrics: [MetricType: Metric] = [:]

    /// Bumped on every load so late answers for an older period are dropped.
    private var generation = 0
    private var metricTasks: [MetricType: Task<Void, Never>] = [:]
    /// Breakdowns shown so far, in the order they were asked for.
    private var shownTypes: [MetricType] = []

    init(website: Website, service: CachingService) {
        self.website = website
        self.service = service
    }

    private var loadTask: Task<Void, Never>?

    /// Shows another period: loading starts at once, in a task owned by the
    /// model, so nothing the view does (menus closing, rows being recycled)
    /// can hold it up or cancel it.
    func select(_ selection: DateSelection, metricTypes: [MetricType]) {
        guard selection != self.selection else { return }
        loadTask?.cancel()
        loadTask = Task { await load(selection, metricTypes: metricTypes) }
    }

    /// Loads the summary, the chart and every breakdown shown so far (at least
    /// `metricTypes`) for `selection`. Returns when the summary and the chart are in.
    func load(_ selection: DateSelection, metricTypes: [MetricType], force: Bool = false) async {
        if force { await service.invalidate() }
        generation += 1
        let generation = generation
        let isNewPeriod = selection != self.selection
        let interval = selection.interval
        let unit = selection.unit
        let websiteID = website.id
        self.selection = selection
        self.interval = interval

        metricTasks.values.forEach { $0.cancel() }
        metricTasks = [:]
        if isNewPeriod {
            isShowingPreviousPeriod = stats != nil
            metrics = [:]
        }
        for type in metricTypes where !shownTypes.contains(type) { shownTypes.append(type) }
        for type in shownTypes { loadMetric(type) }

        if isNewPeriod {
            // Last known numbers for this period, if any, while fresh ones load.
            let cachedStats = await service.cachedStats(websiteID: websiteID, interval: interval)
            let cachedTraffic = await service.cachedTraffic(websiteID: websiteID, interval: interval, unit: unit)
            guard generation == self.generation else { return }
            if let cachedStats, let cachedTraffic {
                stats = cachedStats
                traffic = cachedTraffic.filled(in: interval, unit: unit)
                trafficUnit = unit
                previousTraffic = nil
                isShowingPreviousPeriod = false
            }
            for type in shownTypes where metrics[type] == nil {
                if let items = await service.cachedMetrics(websiteID: websiteID, type: type, interval: interval, limit: Self.previewCount + 1),
                   generation == self.generation, metrics[type] == nil {
                    metrics[type] = .loaded(items)
                }
            }
        }

        let service = service
        let previousInterval = DateSelection.previous(of: interval, unit: unit)
        let summary = Task { () -> Result<(WebsiteStats, TrafficSeries, TrafficSeries?), any Error> in
            do {
                async let stats = service.stats(websiteID: websiteID, interval: interval)
                async let traffic = service.traffic(websiteID: websiteID, interval: interval, unit: unit)
                async let previous = try? service.traffic(websiteID: websiteID, interval: previousInterval, unit: unit)
                return .success(try await (stats, traffic, previous))
            } catch {
                return .failure(error)
            }
        }
        let result = await summary.value
        guard generation == self.generation else { return }
        switch result {
        case .success(let (stats, traffic, previous)):
            self.stats = stats
            self.traffic = traffic.filled(in: interval, unit: unit)
            trafficUnit = unit
            previousTraffic = previous?.filled(in: previousInterval, unit: unit)
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
            // Never leave another period's numbers under this period's title.
            if isShowingPreviousPeriod {
                stats = nil
                traffic = nil
                previousTraffic = nil
            }
        }
        isShowingPreviousPeriod = false
    }

    /// Shows one breakdown: fetched now for the current period, and again
    /// whenever the period changes.
    func show(_ type: MetricType) {
        if !shownTypes.contains(type) { shownTypes.append(type) }
        loadMetric(type)
    }

    /// Fetches one breakdown for the current period, unless it is already loaded or loading.
    private func loadMetric(_ type: MetricType) {
        guard let interval, metricTasks[type] == nil else { return }
        let generation = generation
        let service = service
        let websiteID = website.id
        metricTasks[type] = Task {
            let metric: Metric
            do {
                metric = .loaded(try await service.metrics(websiteID: websiteID, type: type, interval: interval, limit: Self.previewCount + 1))
            } catch is CancellationError {
                return
            } catch {
                metric = .failed(error.localizedDescription)
            }
            guard generation == self.generation else { return }
            metrics[type] = metric
        }
    }

    /// Retries a breakdown that failed.
    func retryMetric(_ type: MetricType) {
        metricTasks[type] = nil
        metrics[type] = nil
        loadMetric(type)
    }
}
