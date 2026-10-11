import AppIntents
import SwiftUI
import WidgetKit

struct SelectTotalIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "All websites"
    static let description = IntentDescription("Adds up several websites into one figure.")

    /// Left empty, the widget adds up every website of the current account.
    @Parameter(title: "Websites", size: [.systemSmall: 10, .systemMedium: 10])
    var websites: [WebsiteEntity]?

    @Parameter(title: "Metric", default: .visitors)
    var metric: WidgetMetric

    @Parameter(title: "Period", default: .today)
    var period: WidgetPeriod

    @Parameter(title: "Compare with previous period", default: true)
    var comparing: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Total \(\.$metric) of \(\.$websites), \(\.$period)") {
            \.$comparing
        }
    }

    init() {}
}

struct TotalEntry: TimelineEntry {
    enum Content {
        case snapshot(TotalSnapshot)
        case message(String)
    }

    let date: Date
    let content: Content
    var widgetKey: String?
    var relevance: TimelineEntryRelevance?
}

struct TotalTimelineProvider: AppIntentTimelineProvider {
    /// One request per website, two when a curve is drawn: the total is the
    /// most expensive widget of the bundle, so the list is capped.
    private static let maxWebsites = 10

    func placeholder(in context: Context) -> TotalEntry {
        TotalEntry(date: .now, content: .snapshot(.sample()))
    }

    func snapshot(for configuration: SelectTotalIntent, in context: Context) async -> TotalEntry {
        if context.isPreview {
            return TotalEntry(date: .now, content: .snapshot(.sample(metric: configuration.metric)))
        }
        return await entry(for: configuration, family: context.family)
    }

    func timeline(for configuration: SelectTotalIntent, in context: Context) async -> Timeline<TotalEntry> {
        let entry = await entry(for: configuration, family: context.family)
        return Timeline(entries: [entry], policy: WidgetRefresh.policy(period: configuration.period))
    }

    private func entry(for configuration: SelectTotalIntent, family: WidgetFamily) async -> TotalEntry {
        let accounts = AccountStore.load()
        guard !accounts.isEmpty else {
            return TotalEntry(date: .now, content: .message(String(localized: "Open the app to connect your Umami server.")))
        }
        let configured = configuration.websites ?? []
        let widgetKey = "total|" + (configured.isEmpty ? "auto" : configured.map(\.id).joined(separator: ","))
            + "|\(configuration.metric.rawValue)"
        let period = WidgetPeriodStore.period(for: widgetKey, configured: configuration.period)

        var targets: [(Account, Website)] = []
        var title = String(localized: "All websites")
        if configured.isEmpty {
            let account = accounts.first { $0.id == AccountStore.selectedAccountID } ?? accounts[0]
            title = account.title
            let websites = await WebsiteEntityQuery.websites(of: account)
            targets = websites.prefix(Self.maxWebsites).map { (account, $0) }
        } else {
            for entity in configured.prefix(Self.maxWebsites) {
                guard let account = accounts.first(where: { $0.id == entity.accountID }) else { continue }
                targets.append((account, Website(id: entity.websiteID, name: entity.name, domain: entity.subtitle)))
            }
        }
        guard !targets.isEmpty else {
            return TotalEntry(date: .now, content: .message(String(localized: "No website yet.")))
        }

        let snapshot = await TotalSnapshot.load(targets: targets, title: title, period: period,
                                                metric: configuration.metric, comparing: configuration.comparing,
                                                includeSeries: family != .systemSmall)
        return TotalEntry(date: .now, content: .snapshot(snapshot), widgetKey: widgetKey,
                          relevance: WidgetRefresh.relevance(change: snapshot.change))
    }
}

struct TotalWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TotalWidget", intent: SelectTotalIntent.self,
                               provider: TotalTimelineProvider()) { entry in
            TotalWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Total")
        .description("Every website of an account added up into one figure.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TotalWidgetEntryView: View {
    let entry: TotalEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch entry.content {
            case .snapshot(let snapshot):
                TotalWidgetView(snapshot: snapshot, showsChart: family != .systemSmall, widgetKey: entry.widgetKey)
            case .message(let message):
                WidgetMessageView(systemImage: "square.stack.3d.up", text: Text(message))
            }
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

#Preview("Total small", as: .systemSmall) {
    TotalWidget()
} timeline: {
    TotalEntry(date: .now, content: .snapshot(.sample()))
}

#Preview("Total medium", as: .systemMedium) {
    TotalWidget()
} timeline: {
    TotalEntry(date: .now, content: .snapshot(.sample()))
}
