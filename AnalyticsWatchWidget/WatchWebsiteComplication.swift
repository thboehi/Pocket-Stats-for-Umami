import AppIntents
import SwiftUI
import WidgetKit

/// Same idea as the iPhone "Website" widget, minus everything a watch face has
/// no room for: no breakdown list, no number of rows, no interactive period.
struct SelectWatchWebsiteIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Website statistics"
    static let description = IntentDescription("Shows the statistics of one of your websites.")

    @Parameter(title: "Website")
    var website: WebsiteEntity?

    @Parameter(title: "Metric", default: .visitors)
    var metric: WidgetMetric

    @Parameter(title: "Period", default: .today)
    var period: WidgetPeriod

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$metric) of \(\.$website), \(\.$period)")
    }

    init() {}
}

struct WatchWebsiteEntry: TimelineEntry {
    enum Content {
        case snapshot(WebsiteSnapshot)
        case message(String)
    }

    let date: Date
    let content: Content
    var relevance: TimelineEntryRelevance?
}

struct WatchWebsiteProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WatchWebsiteEntry {
        WatchWebsiteEntry(date: .now, content: .snapshot(.sample()))
    }

    func snapshot(for configuration: SelectWatchWebsiteIntent, in context: Context) async -> WatchWebsiteEntry {
        if context.isPreview {
            return WatchWebsiteEntry(date: .now, content: .snapshot(.sample(metric: configuration.metric)))
        }
        return await entry(for: configuration, family: context.family)
    }

    func timeline(for configuration: SelectWatchWebsiteIntent, in context: Context) async -> Timeline<WatchWebsiteEntry> {
        let entry = await entry(for: configuration, family: context.family)
        let active: Int? = if case .snapshot(let snapshot) = entry.content { snapshot.activeVisitors } else { nil }
        return Timeline(entries: [entry],
                        policy: WidgetRefresh.policy(period: configuration.period, activeVisitors: active))
    }

    /// What the watch face gallery offers before anyone has configured
    /// anything. It answers synchronously, so it cannot ask the server for the
    /// list of websites: every recommendation leaves the website unset, which
    /// the provider resolves to the first pinned site of the account in front.
    func recommendations() -> [AppIntentRecommendation<SelectWatchWebsiteIntent>] {
        let combinations: [(WidgetMetric, WidgetPeriod)] = [
            (.visitors, .today), (.pageviews, .today), (.visitors, .last7Days),
        ]
        return combinations.map { metric, period in
            let intent = SelectWatchWebsiteIntent()
            intent.metric = metric
            intent.period = period
            return AppIntentRecommendation(intent: intent,
                                           description: Text("\(Text(metric.shortTitle)) · \(Text(period.shortTitle))"))
        }
    }

    private func entry(for configuration: SelectWatchWebsiteIntent, family: WidgetFamily) async -> WatchWebsiteEntry {
        let account: Account
        let website: Website
        switch await WatchComplicationTarget.resolve(configuration.website) {
        case .website(let resolvedAccount, let resolvedWebsite):
            account = resolvedAccount
            website = resolvedWebsite
        case .message(let message):
            return WatchWebsiteEntry(date: .now, content: .message(message))
        }

        do {
            // Only the rectangular family draws a curve, and only it shows who
            // is online: the others would spend a request on nothing.
            let snapshot = try await WebsiteSnapshot.load(account: account, website: website,
                                                          period: configuration.period,
                                                          metric: configuration.metric,
                                                          includeActive: family == .accessoryRectangular,
                                                          includeSeries: family == .accessoryRectangular)
            return WatchWebsiteEntry(date: .now, content: .snapshot(snapshot),
                                     relevance: WidgetRefresh.relevance(change: snapshot.change,
                                                                        activeVisitors: snapshot.activeVisitors))
        } catch {
            return WatchWebsiteEntry(date: .now, content: .message(error.localizedDescription))
        }
    }
}

struct WatchWebsiteComplication: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WatchWebsiteComplication", intent: SelectWatchWebsiteIntent.self,
                               provider: WatchWebsiteProvider()) { entry in
            WatchWebsiteComplicationView(entry: entry)
        }
        .configurationDisplayName("Website")
        .description("One website: the metric of your choice and its trend.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

private struct WatchWebsiteComplicationView: View {
    let entry: WatchWebsiteEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch entry.content {
            case .snapshot(let snapshot):
                switch family {
                case .accessoryCircular: CircularWebsiteWidgetView(snapshot: snapshot)
                case .accessoryCorner: CornerWebsiteWidgetView(snapshot: snapshot)
                case .accessoryInline: InlineWebsiteWidgetView(snapshot: snapshot)
                default: RectangularWebsiteWidgetView(snapshot: snapshot)
                }
            case .message(let message):
                WatchComplicationMessage(systemImage: "globe", message: message, family: family)
            }
        }
        .widgetURL(deepLink)
        .containerBackground(for: .widget) {
            if family == .accessoryCircular { AccessoryWidgetBackground() }
        }
    }

    private var deepLink: URL? {
        guard case .snapshot(let snapshot) = entry.content else { return nil }
        return snapshot.deepLink.url
    }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    WatchWebsiteComplication()
} timeline: {
    WatchWebsiteEntry(date: .now, content: .snapshot(.sample()))
}

#Preview("Circular", as: .accessoryCircular) {
    WatchWebsiteComplication()
} timeline: {
    WatchWebsiteEntry(date: .now, content: .snapshot(.sample()))
}

#Preview("Corner", as: .accessoryCorner) {
    WatchWebsiteComplication()
} timeline: {
    WatchWebsiteEntry(date: .now, content: .snapshot(.sample()))
}
