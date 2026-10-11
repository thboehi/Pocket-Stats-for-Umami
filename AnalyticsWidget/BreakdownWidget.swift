import AppIntents
import SwiftUI
import WidgetKit

struct SelectBreakdownIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Website ranking"
    static let description = IntentDescription("Shows one ranking of a website: pages, referrers, countries…")

    @Parameter(title: "Website")
    var website: WebsiteEntity?

    @Parameter(title: "Ranking", default: .pages)
    var breakdown: WidgetBreakdown

    @Parameter(title: "Period", default: .today)
    var period: WidgetPeriod

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$breakdown) of \(\.$website), \(\.$period)")
    }

    init() {}
}

struct BreakdownEntry: TimelineEntry {
    enum Content {
        case snapshot(BreakdownSnapshot)
        case message(String)
    }

    let date: Date
    let content: Content
    var widgetKey: String?
}

struct BreakdownTimelineProvider: AppIntentTimelineProvider {
    private static func rowCount(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: 3
        case .systemLarge: 8
        default: 4
        }
    }

    func placeholder(in context: Context) -> BreakdownEntry {
        BreakdownEntry(date: .now, content: .snapshot(.sample()))
    }

    func snapshot(for configuration: SelectBreakdownIntent, in context: Context) async -> BreakdownEntry {
        if context.isPreview {
            return BreakdownEntry(date: .now, content: .snapshot(.sample(type: configuration.breakdown.metricType ?? .path,
                                                                          period: configuration.period)))
        }
        return await entry(for: configuration, family: context.family)
    }

    func timeline(for configuration: SelectBreakdownIntent, in context: Context) async -> Timeline<BreakdownEntry> {
        let entry = await entry(for: configuration, family: context.family)
        return Timeline(entries: [entry], policy: WidgetRefresh.policy(period: configuration.period))
    }

    private func entry(for configuration: SelectBreakdownIntent, family: WidgetFamily) async -> BreakdownEntry {
        let accounts = AccountStore.load()
        guard !accounts.isEmpty else {
            return BreakdownEntry(date: .now, content: .message(String(localized: "Open the app to connect your Umami server.")))
        }
        guard let type = configuration.breakdown.metricType else {
            return BreakdownEntry(date: .now, content: .message(String(localized: "Choose a ranking.")))
        }

        let widgetKey = "breakdown|\(configuration.website?.id ?? "auto")|\(configuration.breakdown.rawValue)"
        let period = WidgetPeriodStore.period(for: widgetKey, configured: configuration.period)

        let account: Account
        let website: Website
        if let configured = configuration.website,
           let configuredAccount = accounts.first(where: { $0.id == configured.accountID }) {
            account = configuredAccount
            website = Website(id: configured.websiteID, name: configured.name, domain: configured.subtitle)
        } else {
            account = accounts.first { $0.id == AccountStore.selectedAccountID } ?? accounts[0]
            let websites = await WebsiteEntityQuery.websites(of: account)
            let favorites = FavoritesStore.ids(for: account.id)
            guard let first = websites.first(where: { favorites.contains($0.id) }) ?? websites.first else {
                return BreakdownEntry(date: .now, content: .message(String(localized: "No website yet.")))
            }
            website = first
        }

        do {
            let snapshot = try await BreakdownSnapshot.load(account: account, website: website, period: period,
                                                            type: type, limit: Self.rowCount(for: family))
            return BreakdownEntry(date: .now, content: .snapshot(snapshot), widgetKey: widgetKey)
        } catch {
            return BreakdownEntry(date: .now, content: .message(error.localizedDescription))
        }
    }
}

struct BreakdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "BreakdownWidget", intent: SelectBreakdownIntent.self,
                               provider: BreakdownTimelineProvider()) { entry in
            BreakdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ranking")
        .description("Top pages, referrers, countries… of one website.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct BreakdownWidgetEntryView: View {
    let entry: BreakdownEntry
    @Environment(\.widgetFamily) private var family

    private var rowCount: Int {
        switch family {
        case .systemSmall: 3
        case .systemLarge: 8
        default: 4
        }
    }

    var body: some View {
        Group {
            switch entry.content {
            case .snapshot(let snapshot):
                BreakdownWidgetView(snapshot: snapshot, rowCount: rowCount,
                                    compact: family == .systemSmall, widgetKey: entry.widgetKey)
            case .message(let message):
                WidgetMessageView(systemImage: "list.number", text: Text(message))
            }
        }
        .widgetURL(widgetURL)
        .containerBackground(Color(.systemBackground), for: .widget)
    }

    private var widgetURL: URL? {
        guard case .snapshot(let snapshot) = entry.content else { return nil }
        return snapshot.deepLink.url
    }
}

#Preview("Pages", as: .systemMedium) {
    BreakdownWidget()
} timeline: {
    BreakdownEntry(date: .now, content: .snapshot(.sample()))
}

#Preview("Referrers", as: .systemLarge) {
    BreakdownWidget()
} timeline: {
    BreakdownEntry(date: .now, content: .snapshot(.sample(type: .referrer)))
}

#Preview("Countries", as: .systemSmall) {
    BreakdownWidget()
} timeline: {
    BreakdownEntry(date: .now, content: .snapshot(.sample(type: .country)))
}
