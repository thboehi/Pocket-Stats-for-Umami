import Foundation

enum AppGroup {
    /// `APP_GROUP_ID` from Config/Signing.xcconfig, through the Info.plist of
    /// the app and of the widget: builds signed by another team use their own group.
    static let identifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
        ?? "group.ch.thbo.analyticsforumami"

    /// Shared with the widget. Falls back to `.standard` when the App Group
    /// entitlement is missing (e.g. unsigned builds).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Persists the list of accounts (metadata only) in the App Group defaults so
/// the widget can read it.
enum AccountStore {
    private static let accountsKey = "accounts.v1"
    private static let selectedKey = "accounts.selected"

    static func load() -> [Account] {
        guard let data = AppGroup.defaults.data(forKey: accountsKey) else { return [] }
        return (try? JSONDecoder().decode([Account].self, from: data)) ?? []
    }

    static func save(_ accounts: [Account]) {
        let data = try? JSONEncoder().encode(accounts)
        AppGroup.defaults.set(data, forKey: accountsKey)
    }

    static var selectedAccountID: UUID? {
        get { AppGroup.defaults.string(forKey: selectedKey).flatMap(UUID.init(uuidString:)) }
        set { AppGroup.defaults.set(newValue?.uuidString, forKey: selectedKey) }
    }
}
