import UIKit

/// Home Screen quick actions (touch and hold the app icon): the realtime view
/// of the last website opened, then the recent websites.
@MainActor
enum QuickActions {
    private struct Recent: Codable, Equatable {
        let accountID: UUID
        let websiteID: String
        let name: String
    }

    private static let key = "quickActions.recent"
    private static let maxRecents = 3

    private static var recents: [Recent] {
        get { UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([Recent].self, from: $0) } ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }

    static func recordVisit(to website: Website, account: Account, accounts: [Account]) {
        guard account.kind != .demo else { return }
        let recent = Recent(accountID: account.id, websiteID: website.id, name: website.name)
        recents = Array(([recent] + recents.filter { $0.accountID != recent.accountID || $0.websiteID != recent.websiteID }).prefix(maxRecents))
        update(accounts: accounts)
    }

    /// Rebuilds the quick actions, dropping websites of accounts signed out since.
    static func update(accounts: [Account]) {
        let accountIDs = Set(accounts.map(\.id))
        let recents = recents.filter { accountIDs.contains($0.accountID) }
        self.recents = recents

        var items: [UIApplicationShortcutItem] = []
        if let last = recents.first {
            items.append(item(
                title: String(localized: "Realtime"), subtitle: last.name, systemImage: "dot.radiowaves.left.and.right",
                link: .realtime(accountID: last.accountID, websiteID: last.websiteID)
            ))
        }
        for recent in recents {
            items.append(item(
                title: recent.name, subtitle: nil, systemImage: "chart.xyaxis.line",
                link: .website(accountID: recent.accountID, websiteID: recent.websiteID)
            ))
        }
        UIApplication.shared.shortcutItems = items
    }

    static func handle(_ item: UIApplicationShortcutItem) {
        guard let string = item.userInfo?["url"] as? String, let url = URL(string: string),
              let link = DeepLink(url: url) else { return }
        NavigationRouter.shared.pendingLink = link
    }

    private static func item(title: String, subtitle: String?, systemImage: String, link: DeepLink) -> UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: "ch.thbo.analyticsforumami.open",
            localizedTitle: title,
            localizedSubtitle: subtitle,
            icon: UIApplicationShortcutIcon(systemImageName: systemImage),
            userInfo: ["url": link.url.absoluteString as NSString]
        )
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Launched from a quick action.
        if let item = options.shortcutItem { QuickActions.handle(item) }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem) async -> Bool {
        QuickActions.handle(shortcutItem)
        return true
    }
}
