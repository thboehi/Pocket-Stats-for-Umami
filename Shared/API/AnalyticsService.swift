import Foundation

enum WebsiteScope: String, CaseIterable, Identifiable, Sendable {
    /// Websites owned by the user or one of their teams.
    case mine
    /// Every website on the instance (admin only).
    case all

    var id: String { rawValue }
}

/// Everything the UI and the widget need from an Umami backend. Implemented by
/// `UmamiClient` (real server) and `DemoService` (offline sample data).
protocol AnalyticsService: Sendable {
    var account: Account { get }

    func websites(scope: WebsiteScope) async throws -> [Website]
    func teams() async throws -> [TeamSummary]
    func createWebsite(name: String, domain: String, teamID: String?) async throws -> Website
    func updateWebsite(id: String, name: String, domain: String) async throws -> Website
    func deleteWebsite(id: String) async throws
    func resetWebsite(id: String) async throws

    func stats(websiteID: String, interval: DateInterval) async throws -> WebsiteStats
    func traffic(websiteID: String, interval: DateInterval, unit: TimeUnit) async throws -> TrafficSeries
    func metrics(websiteID: String, type: MetricType, interval: DateInterval, limit: Int) async throws -> [MetricItem]
    func activeVisitors(websiteID: String) async throws -> Int
}

enum AnalyticsServiceFactory {
    static func make(for account: Account) -> any AnalyticsService {
        switch account.kind {
        case .demo: DemoService(account: account)
        case .selfHosted, .cloud, .share: UmamiClient(account: account)
        }
    }
}

enum UmamiError: LocalizedError, Equatable, Sendable {
    case invalidServerURL
    case invalidCredentials
    case unauthorized
    case forbidden
    case notFound
    case badRequest(String?)
    case server(Int, String?)
    case network(String)
    case insecureConnection
    case decoding(String)
    case notAnUmamiServer
    case invalidShareURL
    case shareNotFound

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            String(localized: "The server address is not valid.")
        case .invalidCredentials:
            String(localized: "Incorrect username or password.")
        case .unauthorized:
            String(localized: "Your session has expired. Please sign in again.")
        case .forbidden:
            String(localized: "You don’t have permission to do this.")
        case .notFound:
            String(localized: "This item no longer exists.")
        case .badRequest(let message):
            message ?? String(localized: "The server rejected the request.")
        case .server(let code, let message):
            message ?? String(localized: "Server error (\(code)).")
        case .network(let message):
            message
        case .insecureConnection:
            String(localized: "This server doesn’t use HTTPS. For your security, the app only connects to HTTPS servers, or to servers on your local network.")
        case .decoding:
            String(localized: "Unexpected response from the server. Is it running Umami v2 or later?")
        case .notAnUmamiServer:
            String(localized: "No Umami server was found at this address.")
        case .invalidShareURL:
            String(localized: "This isn’t an Umami share link. It looks like https://umami.example.com/share/…")
        case .shareNotFound:
            String(localized: "This share link doesn’t exist or is no longer shared.")
        }
    }
}
