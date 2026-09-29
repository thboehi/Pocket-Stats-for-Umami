import Foundation

/// A connection to an Umami server. Non-secret metadata only: passwords,
/// tokens and API keys live in the Keychain (see `CredentialStore`).
struct Account: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// Self-hosted Umami, username + password → bearer token.
        case selfHosted
        /// Umami Cloud, API key sent as `x-umami-api-key`.
        case cloud
        /// Public share link of one website (`<server>/share/<id>`), read-only.
        /// `GET /api/share/<id>` returns a token sent as `x-umami-share-token`.
        case share
        /// Offline demo data, used for App Review and first-time exploration.
        case demo
    }

    var id: UUID = UUID()
    var kind: Kind
    /// Web root of the instance (e.g. `https://umami.example.com`). Used for the
    /// dashboard links and the tracking script URL.
    var serverURL: URL
    var username: String?
    var userID: String?
    var isAdmin: Bool = false
    /// Share link accounts: the share ID and the website it gives access to.
    var shareID: String?
    var sharedWebsiteID: String?
    var sharedWebsiteName: String?

    var title: String {
        switch kind {
        case .demo: String(localized: "Demo")
        case .cloud: String(localized: "Umami Cloud")
        case .selfHosted: serverURL.host() ?? serverURL.absoluteString
        case .share: sharedWebsiteName ?? serverURL.host() ?? serverURL.absoluteString
        }
    }

    var subtitle: String? {
        switch kind {
        case .demo: String(localized: "Sample data")
        case .cloud: String(localized: "API key")
        case .selfHosted: username
        case .share: String(localized: "Share link · \(serverURL.host() ?? serverURL.absoluteString)")
        }
    }

    /// Base URL of the REST API.
    var apiBaseURL: URL {
        switch kind {
        case .cloud: URL(string: "https://api.umami.is/v1")!
        case .selfHosted, .share, .demo: serverURL.appending(path: "api")
        }
    }

    var trackingScriptURL: URL {
        serverURL.appending(path: "script.js")
    }

    func dashboardURL(for websiteID: String) -> URL {
        serverURL.appending(path: "websites").appending(path: websiteID)
    }

    func shareURL(for shareID: String) -> URL {
        serverURL.appending(path: "share").appending(path: shareID)
    }

    static let cloudWebURL = URL(string: "https://cloud.umami.is")!
    static let demoURL = URL(string: "https://demo.umami.example")!

    /// Only accounts signed in with a username/password or an API key can edit websites.
    var canManageWebsites: Bool { kind != .share }

    static func makeDemo() -> Account {
        Account(kind: .demo, serverURL: demoURL, username: "demo", isAdmin: true)
    }
}

extension Account {
    /// Normalises user input such as `umami.example.com/`, `http://host:3000/login`.
    static func normalizedServerURL(from input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard var components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty else { return nil }

        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        for suffix in ["/login", "/api", "/dashboard", "/websites"] where path.lowercased().hasSuffix(suffix) {
            path.removeLast(suffix.count)
        }
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.url
    }

    /// Splits a share link such as `https://umami.example.com/share/AbC123` (Umami v2
    /// also appends the website name: `/share/AbC123/example.com`) into the web root
    /// of the instance and the share ID.
    static func parseShareURL(_ input: String) -> (serverURL: URL, shareID: String)? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "https://" + text }
        guard var components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty else { return nil }

        let segments = components.path.split(separator: "/").map(String.init)
        guard let index = segments.lastIndex(where: { $0.lowercased() == "share" }),
              index + 1 < segments.count else { return nil }
        let shareID = segments[index + 1]
        guard !shareID.isEmpty else { return nil }

        // Instances served under a sub-path keep it (`https://host/umami/share/…`).
        components.path = segments[..<index].map { "/" + $0 }.joined()
        components.query = nil
        components.fragment = nil
        guard let serverURL = components.url else { return nil }
        return (serverURL, shareID)
    }
}
