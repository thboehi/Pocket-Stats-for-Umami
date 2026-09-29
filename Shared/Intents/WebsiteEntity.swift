import AppIntents
import Foundation

/// A website of any configured account, selectable in widgets, controls and Shortcuts.
struct WebsiteEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Website"
    static let defaultQuery = WebsiteEntityQuery()

    /// `"<account UUID>|<website id>"`, so websites of different servers never collide.
    let id: String
    let name: String
    let subtitle: String

    var accountID: UUID? { UUID(uuidString: String(id.split(separator: "|").first ?? "")) }
    var websiteID: String { String(id.split(separator: "|").last ?? "") }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }

    init(account: Account, website: Website) {
        id = "\(account.id.uuidString)|\(website.id)"
        name = website.name
        subtitle = website.domain ?? account.title
    }
}

struct WebsiteEntityQuery: EntityStringQuery {
    func entities(for identifiers: [WebsiteEntity.ID]) async throws -> [WebsiteEntity] {
        await Self.allWebsites().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [WebsiteEntity] {
        await Self.allWebsites().filter {
            $0.name.localizedStandardContains(string) || $0.subtitle.localizedStandardContains(string)
        }
    }

    func suggestedEntities() async throws -> [WebsiteEntity] {
        await Self.allWebsites()
    }

    /// Favorites first, then every website of every account.
    static func allWebsites() async -> [WebsiteEntity] {
        await withTaskGroup(of: (Int, [WebsiteEntity]).self) { group in
            for (index, account) in AccountStore.load().enumerated() {
                group.addTask {
                    let websites = await websites(of: account)
                    let favorites = FavoritesStore.ids(for: account.id)
                    let sorted = websites.filter { favorites.contains($0.id) } + websites.filter { !favorites.contains($0.id) }
                    return (index, sorted.map { WebsiteEntity(account: account, website: $0) })
                }
            }
            var results: [(Int, [WebsiteEntity])] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.flatMap(\.1)
        }
    }

    /// The account's own websites, or the whole instance for admins without any.
    static func websites(of account: Account) async -> [Website] {
        let service = AnalyticsServiceFactory.make(for: account)
        let websites = (try? await service.websites(scope: .mine)) ?? []
        if websites.isEmpty, account.isAdmin, account.kind == .selfHosted {
            return (try? await service.websites(scope: .all)) ?? []
        }
        return websites
    }
}

enum WidgetPeriod: String, AppEnum, CaseIterable {
    case today, last24Hours, last7Days, last30Days

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Period"
    static let caseDisplayRepresentations: [WidgetPeriod: DisplayRepresentation] = [
        .today: "Today",
        .last24Hours: "Last 24 hours",
        .last7Days: "Last 7 days",
        .last30Days: "Last 30 days",
    ]

    var preset: DateRangePreset {
        switch self {
        case .today: .today
        case .last24Hours: .last24Hours
        case .last7Days: .last7Days
        case .last30Days: .last30Days
        }
    }

    var unit: TimeUnit {
        switch self {
        case .today, .last24Hours: .hour
        case .last7Days, .last30Days: .day
        }
    }

    var localizedTitle: String {
        String(localized: preset.title)
    }

    /// Compact label for the period button of the widgets.
    var shortTitle: LocalizedStringResource {
        switch self {
        case .today: "Today"
        case .last24Hours: "24h"
        case .last7Days: "7d"
        case .last30Days: "30d"
        }
    }

    var next: WidgetPeriod {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}
