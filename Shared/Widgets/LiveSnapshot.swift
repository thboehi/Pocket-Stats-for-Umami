import Foundation

/// What the Live widget shows: who is on the website right now, and what they
/// are reading. Two requests, or one when the family has no room for pages.
struct LiveSnapshot: Hashable, Sendable {
    let accountID: UUID
    let websiteID: String
    let name: String
    let domain: String?
    let activeVisitors: Int
    /// What those visitors opened in the last half hour, like the app's
    /// realtime view.
    let pages: [MetricItem]
    /// Counts this widget has observed itself, oldest first (`LiveHistoryStore`).
    let history: [TimeSeriesPoint]

    var deepLink: DeepLink { .realtime(accountID: accountID, websiteID: websiteID) }

    /// The window the pages come from, and the span the history covers.
    static let pageWindow: TimeInterval = 30 * 60

    static func load(account: Account, website: Website, includePages: Bool = true,
                     recordHistory: Bool = true, now: Date = .now) async throws -> LiveSnapshot {
        let service = AnalyticsServiceFactory.make(for: account)
        let interval = DateInterval(start: now.addingTimeInterval(-pageWindow), end: now)

        async let active = service.activeVisitors(websiteID: website.id)
        async let pages: [MetricItem] = includePages
            ? (try? service.metrics(websiteID: website.id, type: .path, interval: interval, limit: 4)) ?? []
            : []

        let count = try await active
        let history = recordHistory
            ? LiveHistoryStore.record(count, for: website.id, at: now)
            : LiveHistoryStore.history(for: website.id, now: now)

        return await LiveSnapshot(accountID: account.id, websiteID: website.id, name: website.name,
                                  domain: website.domain, activeVisitors: count, pages: pages,
                                  history: history)
    }

    // MARK: Samples (widget gallery, previews)

    static func sample(name: String = "Alpine Trails Blog", domain: String = "alpinetrails.example",
                       active: Int = 14, shape: [Double] = [4, 6, 5, 9, 12, 10, 8, 11, 16, 13, 12, 14]) -> LiveSnapshot {
        let now = Date.now
        let history = shape.enumerated().map { index, value in
            TimeSeriesPoint(date: now.addingTimeInterval(Double(index - shape.count + 1) * 20 * 60), value: value)
        }
        return LiveSnapshot(
            accountID: UUID(), websiteID: "sample", name: name, domain: domain,
            activeVisitors: active,
            pages: [
                MetricItem(value: "/trails/lac-bleu", count: 6),
                MetricItem(value: "/", count: 4),
                MetricItem(value: "/blog/winter-gear", count: 3),
            ],
            history: history
        )
    }
}
