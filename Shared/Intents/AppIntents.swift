import AppIntents
import SwiftUI
import WidgetKit

/// Opens a website's dashboard, or its realtime view, in the app.
struct OpenWebsiteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open website"
    static let description = IntentDescription("Opens the statistics of a website.")
    static let openAppWhenRun = true

    @Parameter(title: "Website")
    var website: WebsiteEntity?

    @Parameter(title: "Realtime", default: false)
    var realtime: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$website)") {
            \.$realtime
        }
    }

    init() {}

    init(website: WebsiteEntity?, realtime: Bool) {
        self.website = website
        self.realtime = realtime
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let website, let accountID = website.accountID {
            NavigationRouter.shared.pendingLink = realtime
                ? .realtime(accountID: accountID, websiteID: website.websiteID)
                : .website(accountID: accountID, websiteID: website.websiteID)
        }
        return .result()
    }
}

/// "How many visitors today?": answers with the number and a small card.
struct GetVisitorsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get visitors"
    static let description = IntentDescription("Returns the number of visitors of a website for a period.")

    @Parameter(title: "Website")
    var website: WebsiteEntity

    @Parameter(title: "Period", default: .today)
    var period: WidgetPeriod

    static var parameterSummary: some ParameterSummary {
        Summary("Visitors of \(\.$website) for \(\.$period)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog & ShowsSnippetView {
        guard let accountID = website.accountID,
              let account = AccountStore.load().first(where: { $0.id == accountID }) else {
            throw UmamiError.notFound
        }
        let site = Website(id: website.websiteID, name: website.name, domain: website.subtitle)
        let snapshot = try await WebsiteSnapshot.load(account: account, website: site, period: period)
        let visitors = Format.number(snapshot.stats.current.visitors)
        let dialog: IntentDialog = if let change = snapshot.change {
            "\(snapshot.name), \(period.localizedTitle): \(visitors) visitors (\(Format.signedPercent(change)))."
        } else {
            "\(snapshot.name), \(period.localizedTitle): \(visitors) visitors."
        }
        return .result(value: Int(snapshot.stats.current.visitors), dialog: dialog) {
            VisitorsSnippetView(snapshot: snapshot)
        }
    }
}

/// Button of the widgets that switches between today, 24 hours, 7 and 30 days.
struct CycleWidgetPeriodIntent: AppIntent {
    static let title: LocalizedStringResource = "Change period"
    static let isDiscoverable = false

    @Parameter(title: "Widget")
    var widgetKey: String

    init() {}

    init(widgetKey: String) {
        self.widgetKey = widgetKey
    }

    func perform() async throws -> some IntentResult {
        WidgetPeriodStore.cycle(widgetKey)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
