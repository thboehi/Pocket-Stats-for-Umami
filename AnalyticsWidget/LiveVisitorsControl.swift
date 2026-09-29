import AppIntents
import SwiftUI
import WidgetKit

struct SelectControlWebsiteIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Live visitors"

    @Parameter(title: "Website")
    var website: WebsiteEntity?

    init() {}
}

/// Control Center, Lock Screen and Action button: visitors online right now,
/// opens the realtime view.
struct LiveVisitorsControl: ControlWidget {
    struct Value: Sendable {
        var website: WebsiteEntity?
        var activeVisitors: Int?
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: SelectControlWebsiteIntent) -> Value {
            Value(website: configuration.website, activeVisitors: nil)
        }

        func currentValue(configuration: SelectControlWebsiteIntent) async throws -> Value {
            guard let website = configuration.website,
                  let account = AccountStore.load().first(where: { $0.id == website.accountID }) else {
                return Value(website: configuration.website, activeVisitors: nil)
            }
            let active = try? await AnalyticsServiceFactory.make(for: account).activeVisitors(websiteID: website.websiteID)
            return Value(website: website, activeVisitors: active)
        }
    }

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "LiveVisitorsControl", provider: Provider()) { value in
            ControlWidgetButton(action: OpenWebsiteIntent(website: value.website, realtime: true)) {
                Label {
                    Text(value.website?.name ?? String(localized: "Live visitors"))
                    if let active = value.activeVisitors {
                        Text("^[\(active) visitor](inflect: true) online")
                    }
                } icon: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                }
            }
        }
        .displayName("Live visitors")
        .description("Visitors on your website right now. Opens the realtime view.")
    }
}
