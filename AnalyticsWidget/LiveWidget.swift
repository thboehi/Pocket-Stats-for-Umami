import AppIntents
import SwiftUI
import WidgetKit

struct SelectLiveWebsiteIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Live visitors"
    static let description = IntentDescription("Shows who is on your website right now.")

    @Parameter(title: "Website")
    var website: WebsiteEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Visitors on \(\.$website) right now")
    }

    init() {}
}

struct LiveEntry: TimelineEntry {
    enum Content {
        case snapshot(LiveSnapshot)
        case message(String)
    }

    let date: Date
    let content: Content
    var relevance: TimelineEntryRelevance?
}

struct LiveTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LiveEntry {
        LiveEntry(date: .now, content: .snapshot(.sample()))
    }

    func snapshot(for configuration: SelectLiveWebsiteIntent, in context: Context) async -> LiveEntry {
        if context.isPreview { return placeholder(in: context) }
        return await entry(for: configuration, family: context.family, recordHistory: false)
    }

    func timeline(for configuration: SelectLiveWebsiteIntent, in context: Context) async -> Timeline<LiveEntry> {
        let entry = await entry(for: configuration, family: context.family, recordHistory: true)
        let active: Int? = if case .snapshot(let snapshot) = entry.content { snapshot.activeVisitors } else { nil }
        return Timeline(entries: [entry], policy: WidgetRefresh.livePolicy(activeVisitors: active))
    }

    private func entry(for configuration: SelectLiveWebsiteIntent, family: WidgetFamily,
                       recordHistory: Bool) async -> LiveEntry {
        let accounts = AccountStore.load()
        guard !accounts.isEmpty else {
            return LiveEntry(date: .now, content: .message(String(localized: "Open the app to connect your Umami server.")))
        }

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
                return LiveEntry(date: .now, content: .message(String(localized: "No website yet.")))
            }
            website = first
        }

        do {
            // Only the medium family has room for the pages.
            let snapshot = try await LiveSnapshot.load(account: account, website: website,
                                                        includePages: family == .systemMedium,
                                                        recordHistory: recordHistory)
            return LiveEntry(date: .now, content: .snapshot(snapshot),
                             relevance: WidgetRefresh.relevance(change: nil, activeVisitors: snapshot.activeVisitors,
                                                                duration: 20 * 60))
        } catch {
            return LiveEntry(date: .now, content: .message(error.localizedDescription))
        }
    }
}

struct LiveWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "LiveWidget", intent: SelectLiveWebsiteIntent.self,
                               provider: LiveTimelineProvider()) { entry in
            LiveWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Live")
        .description("Visitors on your website right now, and what they are reading.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

private struct LiveWidgetEntryView: View {
    let entry: LiveEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch entry.content {
            case .snapshot(let snapshot):
                switch family {
                case .accessoryRectangular:
                    RectangularLiveWidgetView(snapshot: snapshot)
                case .accessoryCircular:
                    Gauge(value: Double(min(snapshot.activeVisitors, gaugeMax(snapshot))), in: 0...Double(gaugeMax(snapshot))) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                    } currentValueLabel: {
                        Text("\(snapshot.activeVisitors)")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .minimumScaleFactor(0.5)
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .widgetAccentable()
                    .accessibilityLabel(Text("^[\(snapshot.activeVisitors) visitor](inflect: true) online"))
                case .accessoryInline:
                    Label("^[\(snapshot.activeVisitors) visitor](inflect: true) online",
                          systemImage: "dot.radiowaves.left.and.right")
                default:
                    LiveWidgetView(snapshot: snapshot, showsPages: family == .systemMedium)
                }
            case .message(let message):
                WidgetMessageView(systemImage: "dot.radiowaves.left.and.right", text: Text(message))
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

    /// The ring fills against the busiest moment the widget has seen.
    private func gaugeMax(_ snapshot: LiveSnapshot) -> Int {
        max(Int(snapshot.history.map(\.value).max() ?? 0), snapshot.activeVisitors, 1)
    }

    private var widgetURL: URL? {
        guard case .snapshot(let snapshot) = entry.content else { return nil }
        return snapshot.deepLink.url
    }
}

#Preview("Live small", as: .systemSmall) {
    LiveWidget()
} timeline: {
    LiveEntry(date: .now, content: .snapshot(.sample()))
}

#Preview("Live medium", as: .systemMedium) {
    LiveWidget()
} timeline: {
    LiveEntry(date: .now, content: .snapshot(.sample()))
}
