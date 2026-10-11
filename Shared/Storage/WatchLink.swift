import Foundation
import WatchConnectivity

// MARK: - What travels

/// Everything the watch needs to reach the same Umami servers as the iPhone.
///
/// An App Group is shared between an app and its extensions on one device,
/// never between two devices: the watch starts with empty stores, and only the
/// iPhone can fill them.
struct WatchSyncPayload: Codable, Sendable, Equatable {
    /// The secrets of one account. The watch signs in again by itself when a
    /// token expires, exactly like the phone does, so it needs what
    /// `UmamiClient.refreshToken()` uses: the password, or the API key.
    struct Secrets: Codable, Sendable, Equatable {
        var token: String?
        var password: String?
        var apiKey: String?
    }

    /// Also makes every send different from the last one, which is what tells
    /// the system there is a new context to deliver.
    var date = Date.now
    var accounts: [Account] = []
    var selectedAccountID: UUID?
    /// Pinned websites, per account ID.
    var favorites: [String: [String]] = [:]
    /// Per account ID.
    var secrets: [String: Secrets] = [:]

    /// Reads the phone.
    static func current() -> WatchSyncPayload {
        let accounts = AccountStore.load()
        var payload = WatchSyncPayload(accounts: accounts, selectedAccountID: AccountStore.selectedAccountID)
        for account in accounts {
            let key = account.id.uuidString
            let favorites = FavoritesStore.ids(for: account.id)
            if !favorites.isEmpty { payload.favorites[key] = favorites }
            payload.secrets[key] = Secrets(token: CredentialStore.get(.token, for: account.id),
                                           password: CredentialStore.get(.password, for: account.id),
                                           apiKey: CredentialStore.get(.apiKey, for: account.id))
        }
        return payload
    }

    /// Replaces what the watch knows. An account the phone no longer has loses
    /// its secrets here too, rather than lingering in the watch Keychain.
    func apply() {
        let kept = Set(accounts.map(\.id))
        for account in AccountStore.load() where !kept.contains(account.id) {
            CredentialStore.deleteAll(for: account.id)
            FavoritesStore.removeAll(for: account.id)
        }
        for account in accounts {
            let secrets = secrets[account.id.uuidString]
            CredentialStore.set(secrets?.token, .token, for: account.id)
            CredentialStore.set(secrets?.password, .password, for: account.id)
            CredentialStore.set(secrets?.apiKey, .apiKey, for: account.id)
            FavoritesStore.set(favorites[account.id.uuidString] ?? [], for: account.id)
        }
        AccountStore.save(accounts)
        AccountStore.selectedAccountID = selectedAccountID ?? accounts.first?.id
    }
}

extension Notification.Name {
    /// Posted on the watch once the iPhone's state has been written to its stores.
    static let watchSyncDidChange = Notification.Name("ch.thbo.analyticsforumami.watchSyncDidChange")
}

// MARK: - The link

/// The device-to-device link. A WatchConnectivity transfer goes straight from
/// the iPhone to the watch over an encrypted link; nothing passes through a
/// server, which is what lets the secrets travel at all.
///
/// `@unchecked Sendable`: the only stored property is a `let`, but `WCSession`
/// itself makes no promise. Its delegate methods arrive on a background queue.
final class WatchLink: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchLink()

    /// `nil` on an iPad: it has no watch to talk to.
    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    private override init() { super.init() }

    /// Safe to call more than once.
    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    private func applyReceived(_ context: [String: Any]) {
        guard let data = context[Self.payloadKey] as? Data,
              let payload = try? JSONDecoder().decode(WatchSyncPayload.self, from: data) else { return }
        payload.apply()
        Task { @MainActor in
            NotificationCenter.default.post(name: .watchSyncDidChange, object: nil)
        }
    }

    private static let payloadKey = "payload"
    private static let syncRequest = "sync"

    // MARK: Delegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: (any Error)?) {
        guard state == .activated else { return }
        #if os(iOS)
        send()
        #else
        // Whatever arrived while the watch app was not running.
        applyReceived(session.receivedApplicationContext)
        if AccountStore.load().isEmpty { requestSync() }
        #endif
    }

    #if os(iOS)

    /// Pushes the accounts and their secrets. "Latest state wins": the system
    /// keeps one context per app and hands it over whenever the watch comes
    /// back, so there is no queue to drain and no stale state to replay.
    func send() {
        guard let session, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(WatchSyncPayload.current()) else { return }
        try? session.updateApplicationContext([Self.payloadKey: data])
    }

    /// The watch found itself empty and asked. Answering wakes this app in the
    /// background if it was not running.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message[Self.syncRequest] != nil else { return }
        send()
    }

    /// Switching to another watch: the session is handed over, then reactivated.
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// A watch was paired, or the watch app was installed.
    func sessionWatchStateDidChange(_ session: WCSession) {
        send()
    }

    #else

    /// Asks the iPhone for a fresh copy. The system wakes the iPhone app in the
    /// background to answer.
    func requestSync() {
        guard let session, session.activationState == .activated else { return }
        session.sendMessage([Self.syncRequest: true], replyHandler: nil, errorHandler: { _ in })
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyReceived(applicationContext)
    }

    #endif
}
