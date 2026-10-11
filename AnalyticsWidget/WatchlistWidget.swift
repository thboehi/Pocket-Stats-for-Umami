import AppIntents
import SwiftUI
import WidgetKit

struct SelectWatchlistIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Websites"
    static let description = IntentDescription("Shows one metric for several websites.")

    @Parameter(title: "Websites", size: [.systemSmall: 3, .systemMedium: 4, .systemLarge: 8])
    var websites: [WebsiteEntity]?

    @Parameter(title: "Metric", default: .visitors)
    var metric: WidgetMetric

    @Parameter(title: "Period", default: .today)
    var period: WidgetPeriod

    @Parameter(title: "Rows", default: .automatic)
    var rows: WatchlistRows

    @Parameter(title: "Sort by", default: .custom)
    var sort: WatchlistSort

    @Parameter(title: "Compare with previous period", default: true)
    var comparing: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$metric) of \(\.$websites), \(\.$period)") {
            \.$sort
            \.$rows
            \.$comparing
        }
    }

    init() {}
}

struct WatchlistEntry: TimelineEntry {
    let date: Date
    let period: WidgetPeriod
    var metric: WidgetMetric = .visitors
    let snapshots: [WebsiteSnapshot]
    var rows: Int = 3
    var widgetKey: String?
    var message: String?
    var relevance: TimelineEntryRelevance?
}

struct WatchlistTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WatchlistEntry {
        WatchlistEntry(date: .now, period: .today, snapshots: WebsiteSnapshot.samples,
                       rows: WatchlistRows.automatic(for: context.family))
    }

    func snapshot(for configuration: SelectWatchlistIntent, in context: Context) async -> WatchlistEntry {
        if context.isPreview {
            return WatchlistEntry(date: .now, period: configuration.period, metric: configuration.metric,
                                  snapshots: WebsiteSnapshot.samples.map { $0.previewed(as: configuration.metric) },
                                  rows: configuration.rows.resolved(for: context.family))
        }
        return await entry(for: configuration, family: context.family)
    }

    func timeline(for configuration: SelectWatchlistIntent, in context: Context) async -> Timeline<WatchlistEntry> {
        let entry = await entry(for: configuration, family: context.family)
        return Timeline(entries: [entry], policy: WidgetRefresh.policy(period: entry.period))
    }

    private func entry(for configuration: SelectWatchlistIntent, family: WidgetFamily) async -> WatchlistEntry {
        let accounts = AccountStore.load()
        let configured = configuration.websites ?? []
        let maxRows = configuration.rows.resolved(for: family)
        let widgetKey = "watchlist|" + (configured.isEmpty ? "auto" : configured.map(\.id).joined(separator: ","))
            + "|\(configuration.metric.rawValue)"
        let period = WidgetPeriodStore.period(for: widgetKey, configured: configuration.period)
        guard !accounts.isEmpty else {
            return WatchlistEntry(date: .now, period: period, metric: configuration.metric, snapshots: [], rows: maxRows,
                                  message: String(localized: "Open the app to connect your Umami server."))
        }

        // The configured websites, or the favorites then the other websites of the current account.
        var targets: [(Account, Website)] = []
        if configured.isEmpty {
            let account = accounts.first { $0.id == AccountStore.selectedAccountID } ?? accounts[0]
            let websites = await WebsiteEntityQuery.websites(of: account)
            let favorites = FavoritesStore.ids(for: account.id)
            let ordered = favorites.compactMap { id in websites.first { $0.id == id } } + websites.filter { !favorites.contains($0.id) }
            targets = ordered.prefix(maxRows).map { (account, $0) }
        } else {
            for entity in configured.prefix(maxRows) {
                guard let account = accounts.first(where: { $0.id == entity.accountID }) else { continue }
                targets.append((account, Website(id: entity.websiteID, name: entity.name, domain: entity.subtitle)))
            }
        }

        let loaded = await withTaskGroup(of: (Int, WebsiteSnapshot?).self) { group in
            for (index, target) in targets.enumerated() {
                group.addTask {
                    // The small family draws no curve: one request per website.
                    (index, try? await WebsiteSnapshot.load(account: target.0, website: target.1, period: period,
                                                            metric: configuration.metric,
                                                            comparing: configuration.comparing,
                                                            includeActive: false,
                                                            includeSeries: family != .systemSmall))
                }
            }
            var results: [(Int, WebsiteSnapshot)] = []
            for await (index, snapshot) in group {
                if let snapshot { results.append((index, snapshot)) }
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
        let snapshots = configuration.sort.sorted(loaded)
        // The Smart Stack should surface the list when one of its sites moves.
        let biggestMove = snapshots.compactMap(\.change).map(abs).max()
        return WatchlistEntry(date: .now, period: period, metric: configuration.metric, snapshots: snapshots,
                              rows: maxRows, widgetKey: widgetKey,
                              message: snapshots.isEmpty ? String(localized: "No website yet.") : nil,
                              relevance: WidgetRefresh.relevance(change: biggestMove))
    }
}

struct WatchlistWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WatchlistWidget", intent: SelectWatchlistIntent.self, provider: WatchlistTimelineProvider()) { entry in
            WatchlistWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Websites")
        .description("Your websites at a glance, like a watchlist.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct WatchlistWidgetEntryView: View {
    let entry: WatchlistEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let message = entry.message {
                WidgetMessageView(systemImage: "globe", text: Text(message))
            } else {
                WatchlistWidgetView(snapshots: entry.snapshots, period: entry.period, metric: entry.metric,
                                    maxRows: entry.rows, widgetKey: entry.widgetKey, family: family)
            }
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

#Preview("Watchlist small", as: .systemSmall) {
    WatchlistWidget()
} timeline: {
    WatchlistEntry(date: .now, period: .today, snapshots: WebsiteSnapshot.samples, rows: 2)
}

#Preview("Watchlist", as: .systemMedium) {
    WatchlistWidget()
} timeline: {
    WatchlistEntry(date: .now, period: .today, snapshots: WebsiteSnapshot.samples, rows: 3)
}

#Preview("Watchlist large", as: .systemLarge) {
    WatchlistWidget()
} timeline: {
    WatchlistEntry(date: .now, period: .today, snapshots: WebsiteSnapshot.samples, rows: 7)
}
