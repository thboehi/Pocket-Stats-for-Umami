#if DEBUG
import Foundation

/// Debug-only launch hooks, used to drive the app from the command line
/// (`SIMCTL_CHILD_*` variables passed to `xcrun simctl launch`). Compiled out of
/// release builds. See docs/DEVELOPMENT.md.
///
/// - `UMAMI_DEBUG_SERVER`, `UMAMI_DEBUG_USER`, `UMAMI_DEBUG_PASSWORD`: sign in.
/// - `UMAMI_DEBUG_SHARE=<share link>`: add a share link account.
/// - `UMAMI_DEBUG_DEMO=1`: add the demo account. `UMAMI_DEBUG_PIN=<id>,<id>` pins
///   demo websites.
/// - `UMAMI_DEBUG_ACCOUNTS=1`: add sample accounts (no credentials) for the
///   screenshots of the accounts panel.
/// - `UMAMI_DEBUG_SCOPE=all`: show all websites (admin).
/// - `UMAMI_DEBUG_LIST_PERIOD=last7Days`: period of the websites list.
/// - `UMAMI_DEBUG_PERIODS=today,last30Days`: the dashboard switches through
///   these periods, one every 4 seconds.
/// - `UMAMI_DEBUG_WEBSITE=<id>`: open this website's dashboard.
/// - `UMAMI_DEBUG_LINK=<deep link>`: open a deep link (`analyticsforumami://…`).
/// - `UMAMI_DEBUG_SCREEN=sections|realtime|code|edit`: then scroll to the
///   breakdowns or open that screen (used for the App Store screenshots).
///   `accounts` opens the accounts panel, `home` shows the widgets on a mock
///   Home Screen, `widgets` all the widgets, `settings` opens Settings, `share`
///   the share link form from the welcome screen.
enum DebugLaunch {
    static var environment: [String: String] { ProcessInfo.processInfo.environment }

    @MainActor
    static func apply(to model: AppModel) async {
        let env = environment
        if env["UMAMI_DEBUG_ACCOUNTS"] == "1" {
            model.addSampleAccounts()
        }
        if env["UMAMI_DEBUG_DEMO"] == "1" {
            model.addDemoAccount()
            // Set before any await, so the website list reads them when it's created.
            if let pins = env["UMAMI_DEBUG_PIN"], let account = model.currentAccount {
                FavoritesStore.set(pins.components(separatedBy: ","), for: account.id)
            }
        } else if let link = env["UMAMI_DEBUG_SHARE"] {
            do {
                try await model.signIn(shareLink: link)
            } catch {
                print("DebugLaunch share sign-in failed: \(error.localizedDescription)")
            }
        } else if let server = env["UMAMI_DEBUG_SERVER"], let user = env["UMAMI_DEBUG_USER"], let password = env["UMAMI_DEBUG_PASSWORD"] {
            do {
                try await model.signIn(serverAddress: server, username: user, password: password)
            } catch {
                print("DebugLaunch sign-in failed: \(error.localizedDescription)")
            }
        }
        if let website = env["UMAMI_DEBUG_WEBSITE"] {
            model.pendingWebsiteID = website
        }
        if let link = env["UMAMI_DEBUG_LINK"].flatMap(URL.init(string:)) {
            model.open(link)
        }
    }

    static var screen: String? { environment["UMAMI_DEBUG_SCREEN"] }

    static var initialScope: WebsiteScope? {
        environment["UMAMI_DEBUG_SCOPE"].flatMap(WebsiteScope.init(rawValue:))
    }

    /// Period of the websites list, e.g. `last7Days`.
    static var listPeriod: DateRangePreset? {
        environment["UMAMI_DEBUG_LIST_PERIOD"].flatMap(DateRangePreset.init(rawValue:))
    }

    /// Periods the dashboard switches through, one every 4 seconds, e.g.
    /// `today,last30Days`: checks that every section follows the period.
    static var dashboardPeriods: [DateRangePreset] {
        (environment["UMAMI_DEBUG_PERIODS"] ?? "").split(separator: ",").compactMap { DateRangePreset(rawValue: String($0)) }
    }
}
#endif
