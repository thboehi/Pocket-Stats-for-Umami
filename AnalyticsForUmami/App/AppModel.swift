import AppIntents
import Foundation
import Observation
import WidgetKit

/// App-wide state: the configured accounts and the one currently shown.
@MainActor
@Observable
final class AppModel {
    private(set) var accounts: [Account]
    private(set) var currentAccount: Account?
    /// The accounts panel on the left (see `AccountsDrawer`).
    var isShowingAccounts = false
    /// Whether a swipe from the left edge opens the accounts: only when the
    /// website list is at the root, never over the back gesture of a pushed page.
    var canOpenAccountsFromEdge = true

    init() {
        accounts = AccountStore.load()
        let selected = AccountStore.selectedAccountID
        currentAccount = accounts.first { $0.id == selected } ?? accounts.first
    }

    var service: (any AnalyticsService)? {
        currentAccount.map(AnalyticsServiceFactory.make(for:))
    }

    // MARK: Adding accounts

    func signIn(serverAddress: String, username: String, password: String) async throws {
        guard let serverURL = Account.normalizedServerURL(from: serverAddress) else { throw UmamiError.invalidServerURL }
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let login = try await UmamiClient.login(serverURL: serverURL, username: username, password: password)

        var account = accounts.first { $0.kind == .selfHosted && $0.serverURL == serverURL && $0.username == username }
            ?? Account(kind: .selfHosted, serverURL: serverURL)
        account.username = username
        account.userID = login.user.id
        account.isAdmin = login.user.hasAdminRights
        CredentialStore.set(login.token, .token, for: account.id)
        CredentialStore.set(password, .password, for: account.id)
        upsertAndSelect(account)
    }

    func signIn(apiKey: String) async throws {
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var account = Account(kind: .cloud, serverURL: Account.cloudWebURL)
        CredentialStore.set(apiKey, .apiKey, for: account.id)
        do {
            let user = try await UmamiClient(account: account).currentUser()
            account.username = user?.username
            account.userID = user?.id
        } catch UmamiError.unauthorized, UmamiError.forbidden {
            CredentialStore.deleteAll(for: account.id)
            throw UmamiError.invalidCredentials
        } catch {
            CredentialStore.deleteAll(for: account.id)
            throw error
        }
        upsertAndSelect(account)
    }

    func signIn(shareLink: String) async throws {
        guard let (serverURL, shareID) = Account.parseShareURL(shareLink) else { throw UmamiError.invalidShareURL }
        let share = try await UmamiClient.share(serverURL: serverURL, shareID: shareID)

        var account = accounts.first { $0.kind == .share && $0.serverURL == serverURL && $0.shareID == shareID }
            ?? Account(kind: .share, serverURL: serverURL)
        account.shareID = shareID
        account.sharedWebsiteID = share.websiteId
        CredentialStore.set(share.token, .token, for: account.id)
        // The name is only used as the account title: keep going without it.
        account.sharedWebsiteName = try? await UmamiClient(account: account).websites(scope: .mine).first?.name
        upsertAndSelect(account)
    }

    #if DEBUG
    /// Self-hosted, Cloud and share link accounts without credentials, only
    /// shown in the accounts panel of the screenshots.
    func addSampleAccounts() {
        var share = Account(kind: .share, serverURL: URL(string: "https://stats.example.com")!)
        share.sharedWebsiteName = "Alpine Trails Blog"
        accounts = [
            Account(kind: .selfHosted, serverURL: URL(string: "https://umami.example.com")!, username: "admin"),
            Account(kind: .cloud, serverURL: Account.cloudWebURL, username: "agency"),
            share,
        ]
        AccountStore.save(accounts)
    }
    #endif

    func addDemoAccount() {
        if let demo = accounts.first(where: { $0.kind == .demo }) {
            select(demo)
        } else {
            upsertAndSelect(.makeDemo())
        }
    }

    // MARK: Deep links

    /// Website to open once the main view is ready (set by a widget tap).
    var pendingWebsiteID: Website.ID?
    /// Website whose realtime view should open once its dashboard is shown.
    var pendingRealtimeWebsiteID: Website.ID?

    func open(_ url: URL) {
        if let link = DeepLink(url: url) { open(link) }
    }

    func open(_ link: DeepLink) {
        guard let account = accounts.first(where: { $0.id == link.accountID }) else { return }
        isShowingAccounts = false
        if currentAccount?.id != account.id { select(account) }
        pendingWebsiteID = link.websiteID
        if case .realtime = link { pendingRealtimeWebsiteID = link.websiteID }
    }

    // MARK: Managing accounts

    func select(_ account: Account) {
        currentAccount = account
        AccountStore.selectedAccountID = account.id
        WidgetCenter.shared.reloadAllTimelines()
    }

    func remove(_ account: Account) {
        CredentialStore.deleteAll(for: account.id)
        FavoritesStore.removeAll(for: account.id)
        accounts.removeAll { $0.id == account.id }
        AccountStore.save(accounts)
        if currentAccount?.id == account.id {
            currentAccount = accounts.first
            AccountStore.selectedAccountID = currentAccount?.id
        }
        WidgetCenter.shared.reloadAllTimelines()
        QuickActions.update(accounts: accounts)
    }

    private func upsertAndSelect(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        AccountStore.save(accounts)
        select(account)
        PocketStatsShortcuts.updateAppShortcutParameters()
    }
}
