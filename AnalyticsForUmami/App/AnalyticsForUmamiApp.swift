import SwiftUI

@main
struct AnalyticsForUmamiApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var model = AppModel()
    @State private var router = NavigationRouter.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { model.open($0) }
                // Links from App Intents (Shortcuts, Control Center) and quick actions.
                .task(id: router.pendingLink?.url) {
                    guard let link = router.pendingLink else { return }
                    router.pendingLink = nil
                    model.open(link)
                }
                .task { QuickActions.update(accounts: model.accounts) }
                #if DEBUG
                .task { await DebugLaunch.apply(to: model) }
                #endif
        }
    }
}
