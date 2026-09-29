import AppIntents
import SwiftUI
import WidgetKit

struct SelectWatchlistIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Websites"
    static let description = IntentDescription("Shows the visitors of several websites.")

    @Parameter(title: "Websites", size: [.systemMedium: 3, .systemLarge: 7])
    var websites: [WebsiteEntity]?

    @Parameter(title: "Period", default: .today)
    var period: WidgetPeriod

    init() {}
}

struct WatchlistEntry: TimelineEntry {
    let date: Date
    let period: WidgetPeriod
    let snapshots: [WebsiteSnapshot]
    var widgetKey: String?
    var message: String?
}

struct WatchlistTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WatchlistEntry {
        WatchlistEntry(date: .now, period: .today, snapshots: WebsiteSnapshot.samples)
    }

    func snapshot(for configuration: SelectWatchlistIntent, in context: Context) async -> WatchlistEntry {
        if context.isPreview { return placeholder(in: context) }
        return await entry(for: configuration, family: context.family)
    }

    func timeline(for configuration: SelectWatchlistIntent, in context: Context) async -> Timeline<WatchlistEntry> {
        let entry = await entry(for: configuration, family: context.family)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60)))
    }

    private static func maxRows(for family: WidgetFamily) -> Int {
        family == .systemLarge ? 7 : 3
    }

    private func entry(for configuration: SelectWatchlistIntent, family: WidgetFamily) async -> WatchlistEntry {
        let accounts = AccountStore.load()
        let configured = configuration.websites ?? []
        let widgetKey = "watchlist|" + (configured.isEmpty ? "auto" : configured.map(\.id).joined(separator: ","))
        let period = WidgetPeriodStore.period(for: widgetKey, configured: configuration.period)
        guard !accounts.isEmpty else {
            return WatchlistEntry(date: .now, period: period, snapshots: [],
                                  message: String(localized: "Open the app to connect your Umami server."))
        }

        // The configured websites, or the favorites then the other websites of the current account.
        var targets: [(Account, Website)] = []
        if configured.isEmpty {
            let account = accounts.first { $0.id == AccountStore.selectedAccountID } ?? accounts[0]
            let websites = await WebsiteEntityQuery.websites(of: account)
            let favorites = FavoritesStore.ids(for: account.id)
            let ordered = favorites.compactMap { id in websites.first { $0.id == id } } + websites.filter { !favorites.contains($0.id) }
            targets = ordered.prefix(Self.maxRows(for: family)).map { (account, $0) }
        } else {
            for entity in configured.prefix(Self.maxRows(for: family)) {
                guard let account = accounts.first(where: { $0.id == entity.accountID }) else { continue }
                targets.append((account, Website(id: entity.websiteID, name: entity.name, domain: entity.subtitle)))
            }
        }

        let snapshots = await withTaskGroup(of: (Int, WebsiteSnapshot?).self) { group in
            for (index, target) in targets.enumerated() {
                group.addTask {
                    (index, try? await WebsiteSnapshot.load(account: target.0, website: target.1, period: period, includeActive: false))
                }
            }
            var results: [(Int, WebsiteSnapshot)] = []
            for await (index, snapshot) in group {
                if let snapshot { results.append((index, snapshot)) }
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
        return WatchlistEntry(date: .now, period: period, snapshots: snapshots, widgetKey: widgetKey,
                              message: snapshots.isEmpty ? String(localized: "No website yet.") : nil)
    }
}

struct WatchlistWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WatchlistWidget", intent: SelectWatchlistIntent.self, provider: WatchlistTimelineProvider()) { entry in
            WatchlistWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Websites")
        .description("Your websites at a glance, like a watchlist.")
        .supportedFamilies([.systemMedium, .systemLarge])
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
                WatchlistWidgetView(snapshots: entry.snapshots, period: entry.period,
                                    maxRows: family == .systemLarge ? 7 : 3, widgetKey: entry.widgetKey)
            }
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

#Preview("Watchlist", as: .systemMedium) {
    WatchlistWidget()
} timeline: {
    WatchlistEntry(date: .now, period: .today, snapshots: WebsiteSnapshot.samples)
}

#Preview("Watchlist large", as: .systemLarge) {
    WatchlistWidget()
} timeline: {
    WatchlistEntry(date: .now, period: .today, snapshots: WebsiteSnapshot.samples)
}
