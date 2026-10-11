import SwiftUI

@main
struct PocketStatsWatchApp: App {
    init() {
        #if DEBUG
        WatchDebugLaunch.apply()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
