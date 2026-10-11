import AppIntents
import SwiftUI
import WidgetKit

struct SelectWatchLiveIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Live visitors"
    static let description = IntentDescription("Shows who is on your website right now.")

    @Parameter(title: "Website")
    var website: WebsiteEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Visitors on \(\.$website) right now")
    }

    init() {}
}

struct WatchLiveEntry: TimelineEntry {
    enum Content {
        case snapshot(LiveSnapshot)
        case message(String)
    }

    let date: Date
    let content: Content
    var relevance: TimelineEntryRelevance?
}

struct WatchLiveProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WatchLiveEntry {
        WatchLiveEntry(date: .now, content: .snapshot(.sample()))
    }

    func snapshot(for configuration: SelectWatchLiveIntent, in context: Context) async -> WatchLiveEntry {
        if context.isPreview { return placeholder(in: context) }
        return await entry(for: configuration, recordHistory: false)
    }

    func timeline(for configuration: SelectWatchLiveIntent, in context: Context) async -> Timeline<WatchLiveEntry> {
        let entry = await entry(for: configuration, recordHistory: true)
        let active: Int? = if case .snapshot(let snapshot) = entry.content { snapshot.activeVisitors } else { nil }
        return Timeline(entries: [entry], policy: WidgetRefresh.livePolicy(activeVisitors: active))
    }

    /// One entry in the watch face gallery: the website is left unset, and the
    /// provider resolves it like the website complication does.
    func recommendations() -> [AppIntentRecommendation<SelectWatchLiveIntent>] {
        [AppIntentRecommendation(intent: SelectWatchLiveIntent(), description: Text("Live"))]
    }

    private func entry(for configuration: SelectWatchLiveIntent, recordHistory: Bool) async -> WatchLiveEntry {
        let account: Account
        let website: Website
        switch await WatchComplicationTarget.resolve(configuration.website) {
        case .website(let resolvedAccount, let resolvedWebsite):
            account = resolvedAccount
            website = resolvedWebsite
        case .message(let message):
            return WatchLiveEntry(date: .now, content: .message(message))
        }

        do {
            // No family here has room for the pages: one request, and the
            // history the complication has sampled itself.
            let snapshot = try await LiveSnapshot.load(account: account, website: website,
                                                        includePages: false, recordHistory: recordHistory)
            return WatchLiveEntry(date: .now, content: .snapshot(snapshot),
                                  relevance: WidgetRefresh.relevance(change: nil,
                                                                     activeVisitors: snapshot.activeVisitors,
                                                                     duration: 20 * 60))
        } catch {
            return WatchLiveEntry(date: .now, content: .message(error.localizedDescription))
        }
    }
}

struct WatchLiveComplication: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WatchLiveComplication", intent: SelectWatchLiveIntent.self,
                               provider: WatchLiveProvider()) { entry in
            WatchLiveComplicationView(entry: entry)
        }
        .configurationDisplayName("Live")
        .description("Visitors on your website right now.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

private struct WatchLiveComplicationView: View {
    let entry: WatchLiveEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch entry.content {
            case .snapshot(let snapshot):
                switch family {
                case .accessoryCircular: circular(snapshot)
                case .accessoryCorner: corner(snapshot)
                case .accessoryInline:
                    Label("^[\(snapshot.activeVisitors) visitor](inflect: true) online",
                          systemImage: "dot.radiowaves.left.and.right")
                default: RectangularLiveWidgetView(snapshot: snapshot)
                }
            case .message(let message):
                WatchComplicationMessage(systemImage: "dot.radiowaves.left.and.right", message: message, family: family)
            }
        }
        .widgetURL(deepLink)
        .containerBackground(for: .widget) {
            if family == .accessoryCircular { AccessoryWidgetBackground() }
        }
    }

    private func circular(_ snapshot: LiveSnapshot) -> some View {
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
    }

    private func corner(_ snapshot: LiveSnapshot) -> some View {
        Text("\(snapshot.activeVisitors)")
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .minimumScaleFactor(0.5)
            .widgetAccentable()
            .widgetLabel {
                Gauge(value: Double(min(snapshot.activeVisitors, gaugeMax(snapshot))), in: 0...Double(gaugeMax(snapshot))) {
                    Text(snapshot.name)
                }
            }
            .accessibilityLabel(Text("^[\(snapshot.activeVisitors) visitor](inflect: true) online"))
    }

    /// The ring fills against the busiest moment the complication has seen.
    private func gaugeMax(_ snapshot: LiveSnapshot) -> Int {
        max(Int(snapshot.history.map(\.value).max() ?? 0), snapshot.activeVisitors, 1)
    }

    private var deepLink: URL? {
        guard case .snapshot(let snapshot) = entry.content else { return nil }
        return snapshot.deepLink.url
    }
}

#Preview("Live rectangular", as: .accessoryRectangular) {
    WatchLiveComplication()
} timeline: {
    WatchLiveEntry(date: .now, content: .snapshot(.sample()))
}

#Preview("Live circular", as: .accessoryCircular) {
    WatchLiveComplication()
} timeline: {
    WatchLiveEntry(date: .now, content: .snapshot(.sample()))
}
