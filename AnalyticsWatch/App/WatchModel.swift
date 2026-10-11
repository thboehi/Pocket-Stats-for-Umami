import Observation
import SwiftUI

/// What the watch shows: the accounts the iPhone sent over, the websites of the
/// one in front, and one figure per website.
@MainActor
@Observable
final class WatchModel {
    private(set) var accounts: [Account] = []
    private(set) var account: Account?
    private(set) var websites: [Website] = []
    private(set) var snapshots: [Website.ID: WebsiteSnapshot] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Chosen on the watch and kept there: a glance at the wrist rarely wants
    /// the same window as the phone.
    var period: WidgetPeriod = .today

    init() {
        readStores()
    }

    /// Called at launch and whenever the iPhone has sent a new state.
    func readStores() {
        accounts = AccountStore.load()
        let selected = AccountStore.selectedAccountID
        let current = accounts.first { $0.id == selected } ?? accounts.first
        if current?.id != account?.id {
            account = current
            websites = []
            snapshots = [:]
        }
    }

    /// A complication was tapped. The website it points at can only be pushed
    /// once the list has arrived, so the link waits here until then.
    private(set) var pendingLink: DeepLink?

    func open(_ link: DeepLink) {
        if let account = accounts.first(where: { $0.id == link.accountID }) { select(account) }
        pendingLink = link
    }

    /// The website a pending link points at, once it is loaded. Taking it
    /// clears the link, so coming back from the website does not push it again.
    func takePendingWebsite() -> Website? {
        guard let pendingLink, let website = websites.first(where: { $0.id == pendingLink.websiteID }) else { return nil }
        self.pendingLink = nil
        return website
    }

    func select(_ account: Account) {
        guard account.id != self.account?.id else { return }
        self.account = account
        AccountStore.selectedAccountID = account.id
        websites = []
        snapshots = [:]
    }

    /// The website list once, then one request per website: this list draws no
    /// curve, so it never asks for one.
    func load(force: Bool = false) async {
        guard let account else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if websites.isEmpty || force {
            let loaded: [Website]
            do {
                loaded = try await loadWebsites(for: account)
            } catch {
                guard isStillCurrent(account) else { return }
                errorMessage = error.localizedDescription
                return
            }
            // The iPhone can send a new state, and the reader can switch
            // accounts, while this is in flight: those results are not ours.
            guard isStillCurrent(account) else { return }
            websites = loaded
            guard !websites.isEmpty else {
                errorMessage = String(localized: "No website yet.")
                return
            }
        }

        let period = period
        let websites = websites
        let loaded = await withTaskGroup(of: (Website.ID, WebsiteSnapshot?).self) { group in
            for website in websites {
                group.addTask {
                    (website.id, try? await WebsiteSnapshot.load(account: account, website: website, period: period,
                                                                 includeActive: false, includeSeries: false))
                }
            }
            var byID: [Website.ID: WebsiteSnapshot] = [:]
            for await (id, snapshot) in group {
                if let snapshot { byID[id] = snapshot }
            }
            return byID
        }
        guard isStillCurrent(account) else { return }
        snapshots = loaded
        if snapshots.isEmpty {
            errorMessage = String(localized: "Could not reach the server.")
        }
    }

    /// `false` once the account in front is no longer the one a request was
    /// started for.
    private func isStillCurrent(_ account: Account) -> Bool {
        self.account?.id == account.id
    }

    /// Pinned websites first, like the iPhone list and the widgets.
    private func loadWebsites(for account: Account) async throws -> [Website] {
        let service = AnalyticsServiceFactory.make(for: account)
        var loaded = try await service.websites(scope: .mine)
        if loaded.isEmpty, account.isAdmin, account.kind == .selfHosted {
            loaded = try await service.websites(scope: .all)
        }
        let favorites = FavoritesStore.ids(for: account.id)
        return favorites.compactMap { id in loaded.first { $0.id == id } }
            + loaded.filter { !favorites.contains($0.id) }
    }
}
