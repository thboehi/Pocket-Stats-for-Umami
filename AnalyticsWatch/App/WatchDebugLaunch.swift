#if DEBUG
import SwiftUI

/// Debug-only launch hooks for the watch, the counterpart of the iPhone's
/// `DebugLaunch`: they drive the app from the command line
/// (`SIMCTL_CHILD_*` variables passed to `xcrun simctl launch`) so the screens
/// can be captured without touching the simulator. Compiled out of release
/// builds. See docs/DEVELOPMENT.md.
///
/// - `UMAMI_DEBUG_DEMO=1`: put the demo account in the watch's own store, so
///   the screens can be captured without a paired iPhone sending one over.
///   `UMAMI_DEBUG_PIN=<id>,<id>` pins demo websites, like on the iPhone.
/// - `UMAMI_DEBUG_WEBSITE=first|<id>`: open that website's screen at launch.
/// - `UMAMI_DEBUG_SCREEN=complications`: show every complication with sample
///   data, instead of the app.
/// - `UMAMI_DEBUG_SCROLL=bottom|center`: where a website screen opens, so the
///   metrics under the chart can be captured too.
enum WatchDebugLaunch {
    static var environment: [String: String] { ProcessInfo.processInfo.environment }

    /// Runs before the model reads the stores.
    static func apply() {
        guard environment["UMAMI_DEBUG_DEMO"] == "1" else { return }
        var accounts = AccountStore.load()
        let demo = accounts.first { $0.kind == .demo } ?? .makeDemo()
        if !accounts.contains(where: { $0.id == demo.id }) {
            accounts.append(demo)
            AccountStore.save(accounts)
        }
        AccountStore.selectedAccountID = demo.id
        if let pins = environment["UMAMI_DEBUG_PIN"] {
            FavoritesStore.set(pins.components(separatedBy: ","), for: demo.id)
        }
    }

    @MainActor
    static func website(in model: WatchModel) -> Website? {
        guard let wanted = environment["UMAMI_DEBUG_WEBSITE"] else { return nil }
        return wanted == "first" ? model.websites.first : model.websites.first { $0.id == wanted }
    }

    static var showsComplicationGallery: Bool { environment["UMAMI_DEBUG_SCREEN"] == "complications" }

    /// Demo mode owns the stores: letting the bridge run would overwrite them
    /// with whatever the paired iPhone last sent, pins included.
    static var isDemo: Bool { environment["UMAMI_DEBUG_DEMO"] == "1" }

    static var scrollAnchor: UnitPoint {
        switch environment["UMAMI_DEBUG_SCROLL"] {
        case "bottom": .bottom
        case "center": .center
        default: .top
        }
    }
}
#endif
