import SwiftUI
import WidgetKit

/// Which website a complication is about: the one it was configured with, or —
/// as long as nobody has configured it — the first pinned website of the
/// account in front, exactly like the iPhone widgets.
///
/// The accounts are the ones the iPhone sent over `WatchLink`, read from the
/// watch's own App Group, so a complication works whether the iPhone is in
/// range or not.
enum WatchComplicationTarget {
    case website(Account, Website)
    case message(String)

    static func resolve(_ configured: WebsiteEntity?) async -> WatchComplicationTarget {
        let accounts = AccountStore.load()
        guard !accounts.isEmpty else {
            return .message(String(localized: "Open Pocket Stats on your iPhone to send your servers to the watch."))
        }
        if let configured, let account = accounts.first(where: { $0.id == configured.accountID }) {
            return .website(account, Website(id: configured.websiteID, name: configured.name,
                                             domain: configured.subtitle))
        }
        let account = accounts.first { $0.id == AccountStore.selectedAccountID } ?? accounts[0]
        let websites = await WebsiteEntityQuery.websites(of: account)
        let favorites = FavoritesStore.ids(for: account.id)
        guard let first = websites.first(where: { favorites.contains($0.id) }) ?? websites.first else {
            return .message(String(localized: "No website yet."))
        }
        return .website(account, first)
    }
}

/// The same message in whatever room the family leaves: a line, a glyph, or
/// the glyph with the text under it.
struct WatchComplicationMessage: View {
    let systemImage: String
    let message: String
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(message)
        case .accessoryCircular:
            Image(systemName: systemImage)
                .font(.title3)
        case .accessoryCorner:
            Image(systemName: systemImage)
                .font(.title3)
                .widgetLabel(message)
        default:
            WidgetMessageView(systemImage: systemImage, text: Text(message))
        }
    }
}
