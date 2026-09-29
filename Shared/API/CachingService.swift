import Foundation

/// Wraps a service to memoize read requests for a short time and share the
/// ones in flight: the list rows, the dashboard and its sections never fetch
/// the same data twice, and reopening a website shows its last numbers at once
/// (see `cachedStats` & co.) while fresh ones load.
final class CachingService: AnalyticsService {
    let base: any AnalyticsService
    private let store = ResponseStore()

    init(_ base: any AnalyticsService) {
        self.base = base
    }

    var account: Account { base.account }

    /// Forgets in-flight and recent requests (kept values stay available to `cached…`).
    func invalidate() async {
        await store.invalidate()
    }

    // MARK: Websites (not cached, mutations invalidate)

    func websites(scope: WebsiteScope) async throws -> [Website] { try await base.websites(scope: scope) }
    func teams() async throws -> [TeamSummary] { try await base.teams() }

    func createWebsite(name: String, domain: String, teamID: String?) async throws -> Website {
        try await base.createWebsite(name: name, domain: domain, teamID: teamID)
    }

    func updateWebsite(id: String, name: String, domain: String) async throws -> Website {
        try await base.updateWebsite(id: id, name: name, domain: domain)
    }

    func deleteWebsite(id: String) async throws {
        try await base.deleteWebsite(id: id)
        await store.remove(websiteID: id)
    }

    func resetWebsite(id: String) async throws {
        try await base.resetWebsite(id: id)
        await store.remove(websiteID: id)
    }

    // MARK: Statistics

    func stats(websiteID: String, interval: DateInterval) async throws -> WebsiteStats {
        try await store.value(for: .init("stats", websiteID, interval)) { [base] in
            try await base.stats(websiteID: websiteID, interval: interval)
        }
    }

    func traffic(websiteID: String, interval: DateInterval, unit: TimeUnit) async throws -> TrafficSeries {
        try await store.value(for: .init("traffic", websiteID, interval, unit.rawValue)) { [base] in
            try await base.traffic(websiteID: websiteID, interval: interval, unit: unit)
        }
    }

    func metrics(websiteID: String, type: MetricType, interval: DateInterval, limit: Int) async throws -> [MetricItem] {
        try await store.value(for: .init("metrics", websiteID, interval, "\(type.rawValue)/\(limit)")) { [base] in
            try await base.metrics(websiteID: websiteID, type: type, interval: interval, limit: limit)
        }
    }

    func activeVisitors(websiteID: String) async throws -> Int {
        try await base.activeVisitors(websiteID: websiteID)
    }

    // MARK: Last known values

    func cachedStats(websiteID: String, interval: DateInterval) async -> WebsiteStats? {
        await store.cached(.init("stats", websiteID, interval))
    }

    func cachedTraffic(websiteID: String, interval: DateInterval, unit: TimeUnit) async -> TrafficSeries? {
        await store.cached(.init("traffic", websiteID, interval, unit.rawValue))
    }

    func cachedMetrics(websiteID: String, type: MetricType, interval: DateInterval, limit: Int) async -> [MetricItem]? {
        await store.cached(.init("metrics", websiteID, interval, "\(type.rawValue)/\(limit)"))
    }
}

private actor ResponseStore {
    struct Key: Hashable {
        let kind: String
        let websiteID: String
        let interval: DateInterval
        let detail: String

        init(_ kind: String, _ websiteID: String, _ interval: DateInterval, _ detail: String = "") {
            self.kind = kind
            self.websiteID = websiteID
            self.interval = interval
            self.detail = detail
        }
    }

    /// Answers younger than this are reused.
    private static let maxAge: TimeInterval = 60
    /// A request still running after this long is likely stuck: callers
    /// start a new one instead of waiting for it.
    private static let maxWait: TimeInterval = 8

    private struct Entry {
        let task: Task<any Sendable, any Error>
        let started: Date
        var finished = false
    }

    private var inFlight: [Key: Entry] = [:]
    private var values: [Key: any Sendable] = [:]

    func value<T: Sendable>(for key: Key, fetch: @escaping @Sendable () async throws -> T) async throws -> T {
        if let entry = inFlight[key] {
            let age = Date.now.timeIntervalSince(entry.started)
            if entry.finished ? age < Self.maxAge : age < Self.maxWait,
               let value = try? await entry.task.value as? T {
                return value
            }
        }
        // The request is not tied to the caller: if the view that asked goes
        // away, the result still lands here for the next one.
        let task = Task<any Sendable, any Error> { try await fetch() }
        inFlight[key] = Entry(task: task, started: .now)
        do {
            let value = try await task.value as! T
            values[key] = value
            if inFlight[key]?.task == task { inFlight[key]?.finished = true }
            return value
        } catch {
            if inFlight[key]?.task == task { inFlight[key] = nil }
            throw error
        }
    }

    func cached<T: Sendable>(_ key: Key) -> T? {
        values[key] as? T
    }

    func invalidate() {
        inFlight = [:]
    }

    func remove(websiteID: String) {
        inFlight = inFlight.filter { $0.key.websiteID != websiteID }
        values = values.filter { $0.key.websiteID != websiteID }
    }
}
