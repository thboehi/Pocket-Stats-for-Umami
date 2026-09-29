import Foundation
import Observation

/// `analyticsforumami://website/<account UUID>/<website id>` opens a dashboard,
/// `analyticsforumami://realtime/<account UUID>/<website id>` its realtime view.
/// Used by the widgets, the control, Shortcuts and the Home Screen quick actions.
enum DeepLink: Equatable {
    case website(accountID: UUID, websiteID: String)
    case realtime(accountID: UUID, websiteID: String)

    static let scheme = "analyticsforumami"

    var url: URL {
        switch self {
        case .website(let accountID, let websiteID):
            URL(string: "\(Self.scheme)://website/\(accountID.uuidString)/\(websiteID)")!
        case .realtime(let accountID, let websiteID):
            URL(string: "\(Self.scheme)://realtime/\(accountID.uuidString)/\(websiteID)")!
        }
    }

    var accountID: UUID {
        switch self {
        case .website(let accountID, _), .realtime(let accountID, _): accountID
        }
    }

    var websiteID: String {
        switch self {
        case .website(_, let websiteID), .realtime(_, let websiteID): websiteID
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, let accountID = UUID(uuidString: parts[0]) else { return nil }
        switch url.host() {
        case "website": self = .website(accountID: accountID, websiteID: parts[1])
        case "realtime": self = .realtime(accountID: accountID, websiteID: parts[1])
        default: return nil
        }
    }
}

/// Hands deep links from App Intents and quick actions (which run outside the
/// SwiftUI hierarchy) to the app.
@MainActor
@Observable
final class NavigationRouter {
    static let shared = NavigationRouter()

    var pendingLink: DeepLink?
}
