import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration

struct SelectWebsiteIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Website statistics"
    static let description = IntentDescription("Shows the statistics of one of your websites.")

    @Parameter(title: "Website")
    var website: WebsiteEntity?

    @Parameter(title: "Metric", default: .visitors)
    var metric: WidgetMetric

    @Parameter(title: "Period", default: .today)
    var period: WidgetPeriod

    @Parameter(title: "Details", default: .pages)
    var breakdown: WidgetBreakdown

    @Parameter(title: "Compare with previous period", default: true)
    var comparing: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$metric) of \(\.$website), \(\.$period)") {
            \.$breakdown
            \.$comparing
        }
    }

    init() {}
}

// MARK: - Timeline

struct WebsiteEntry: TimelineEntry {
    enum Content {
        case snapshot(WebsiteSnapshot)
        case noAccount
        case noWebsite
        case failure(String)
    }

    let date: Date
    let content: Content
    var widgetKey: String?
    var relevance: TimelineEntryRelevance?
}

struct WebsiteTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WebsiteEntry {
        WebsiteEntry(date: .now, content: .snapshot(.sample()))
    }

    func snapshot(for configuration: SelectWebsiteIntent, in context: Context) async -> WebsiteEntry {
        // The widget gallery needs an answer right away: show sample data.
        if context.isPreview {
            return WebsiteEntry(date: .now, content: .snapshot(.sample(metric: configuration.metric,
                                                                       breakdownType: configuration.breakdown.metricType)))
        }
        return await entry(for: configuration, family: context.family)
    }

    func timeline(for configuration: SelectWebsiteIntent, in context: Context) async -> Timeline<WebsiteEntry> {
        let entry = await entry(for: configuration, family: context.family)
        let active: Int? = if case .snapshot(let snapshot) = entry.content { snapshot.activeVisitors } else { nil }
        return Timeline(entries: [entry],
                        policy: WidgetRefresh.policy(period: configuration.period, activeVisitors: active))
    }

    private func entry(for configuration: SelectWebsiteIntent, family: WidgetFamily) async -> WebsiteEntry {
        let accounts = AccountStore.load()
        guard !accounts.isEmpty else { return WebsiteEntry(date: .now, content: .noAccount) }

        let widgetKey = "website|\(configuration.website?.id ?? "auto")|\(configuration.metric.rawValue)"
        let period = WidgetPeriodStore.period(for: widgetKey, configured: configuration.period)

        // The configured website, or the first favorite of the current account.
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
                return WebsiteEntry(date: .now, content: .noWebsite)
            }
            website = first
        }

        do {
            let snapshot = try await WebsiteSnapshot.load(account: account, website: website, period: period,
                                                          metric: configuration.metric,
                                                          comparing: configuration.comparing,
                                                          breakdown: family == .systemLarge ? configuration.breakdown.metricType : nil,
                                                          includeSeries: family != .accessoryInline)
            return WebsiteEntry(date: .now, content: .snapshot(snapshot), widgetKey: widgetKey,
                                relevance: WidgetRefresh.relevance(change: snapshot.change,
                                                                   activeVisitors: snapshot.activeVisitors))
        } catch {
            return WebsiteEntry(date: .now, content: .failure(error.localizedDescription))
        }
    }
}

// MARK: - Widget

struct WebsiteWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WebsiteWidget", intent: SelectWebsiteIntent.self, provider: WebsiteTimelineProvider()) { entry in
            WebsiteWidgetView(entry: entry)
        }
        .configurationDisplayName("Website")
        .description("One website: the metric of your choice, its trend and who is online.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct WebsiteWidgetView: View {
    let entry: WebsiteEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch entry.content {
            case .snapshot(let snapshot):
                switch family {
                case .systemMedium: MediumWebsiteWidgetView(snapshot: snapshot, widgetKey: entry.widgetKey)
                case .systemLarge: LargeWebsiteWidgetView(snapshot: snapshot, widgetKey: entry.widgetKey)
                case .accessoryRectangular: RectangularWebsiteWidgetView(snapshot: snapshot)
                case .accessoryCircular: CircularWebsiteWidgetView(snapshot: snapshot)
                case .accessoryInline: InlineWebsiteWidgetView(snapshot: snapshot)
                default: SmallWebsiteWidgetView(snapshot: snapshot, widgetKey: entry.widgetKey)
                }
            case .noAccount:
                WidgetMessageView(systemImage: "person.crop.circle.badge.plus", text: Text("Open the app to connect your Umami server."))
            case .noWebsite:
                WidgetMessageView(systemImage: "globe", text: Text("No website yet."))
            case .failure(let message):
                WidgetMessageView(systemImage: "exclamationmark.triangle", text: Text(message))
            }
        }
        .widgetURL(widgetURL)
        .containerBackground(for: .widget) {
            if family == .accessoryCircular || family == .accessoryRectangular {
                AccessoryWidgetBackground().opacity(family == .accessoryCircular ? 1 : 0)
            } else {
                Color(.systemBackground)
            }
        }
    }

    private var widgetURL: URL? {
        guard case .snapshot(let snapshot) = entry.content else { return nil }
        return snapshot.deepLink.url
    }
}

#Preview("Small", as: .systemSmall) {
    WebsiteWidget()
} timeline: {
    WebsiteEntry(date: .now, content: .snapshot(.sample()))
}

#Preview("Medium", as: .systemMedium) {
    WebsiteWidget()
} timeline: {
    WebsiteEntry(date: .now, content: .snapshot(.sample()))
}

#Preview("Medium · bounce rate", as: .systemMedium) {
    WebsiteWidget()
} timeline: {
    WebsiteEntry(date: .now, content: .snapshot(.sample(metric: .bounceRate)))
}

#Preview("Large", as: .systemLarge) {
    WebsiteWidget()
} timeline: {
    WebsiteEntry(date: .now, content: .snapshot(.sample()))
}

#Preview("Large · referrers", as: .systemLarge) {
    WebsiteWidget()
} timeline: {
    WebsiteEntry(date: .now, content: .snapshot(.sample(metric: .pageviews, breakdownType: .referrer)))
}
