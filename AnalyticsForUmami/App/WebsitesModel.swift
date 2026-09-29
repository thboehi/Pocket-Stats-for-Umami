import Foundation
import Observation
import SwiftUI
import WidgetKit

enum WebsiteSortOrder: String {
    case name, visitors
}

/// Websites of the current account, shared by the sidebar and the dashboards so
/// that edits and deletions show up everywhere at once.
@MainActor
@Observable
final class WebsitesModel {
    let service: CachingService
    var account: Account { service.account }

    private(set) var websites: [Website] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    /// Admins can switch between their own websites and every website on the server.
    var scope: WebsiteScope = .mine {
        didSet { if scope != oldValue { Task { await load() } } }
    }

    /// Summary and visitors line of each website for `period`, shown in the list rows.
    private(set) var rowStats: [Website.ID: WebsiteStats] = [:]
    private(set) var rowSeries: [Website.ID: [TimeSeriesPoint]] = [:]
    /// Bumped by a refresh: rows fetch their figures again, keeping the old
    /// ones on screen until the new ones are in.
    private(set) var figuresGeneration = 0
    private var rowGenerations: [Website.ID: Int] = [:]

    /// Pinned at the top of the list and first in the widgets.
    private(set) var favoriteIDs: [Website.ID]

    var sortOrder: WebsiteSortOrder = WebsiteSortOrder(rawValue: UserDefaults.standard.string(forKey: "websites.sort") ?? "") ?? .name {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: "websites.sort")
            if sortOrder == .visitors { Task { await rankByVisitors() } }
        }
    }

    /// Period of the figures in the list: today unless the user picks another one.
    var period: DateRangePreset = DateRangePreset(rawValue: UserDefaults.standard.string(forKey: "websites.period") ?? "") ?? .today {
        didSet {
            guard period != oldValue else { return }
            UserDefaults.standard.set(period.rawValue, forKey: "websites.period")
            // The old figures mean something else: rows show placeholders
            // until the new ones are in.
            rowStats = [:]
            rowSeries = [:]
            rowGenerations = [:]
            visitorRanking = nil
            if sortOrder == .visitors { Task { await rankByVisitors() } }
        }
    }

    /// Websites by visitors over the period, set once every figure is in, so
    /// rows move only once instead of every time a number arrives.
    private var visitorRanking: [Website.ID]?

    /// Horizontal range of the row lines: today spans the whole day, so the
    /// line grows through the day like in the Stocks app.
    var chartDomain: ClosedRange<Date>? {
        let interval = period.interval()
        guard period == .today, let end = Calendar.current.date(byAdding: .hour, value: 23, to: interval.start) else { return nil }
        return interval.start...end
    }

    init(service: any AnalyticsService) {
        self.service = CachingService(service)
        favoriteIDs = FavoritesStore.ids(for: service.account.id)
        #if DEBUG
        if let scope = DebugLaunch.initialScope { self.scope = scope }
        if let period = DebugLaunch.listPeriod { self.period = period }
        #endif
    }

    var canSeeAllWebsites: Bool {
        account.isAdmin && account.kind == .selfHosted
    }

    func website(id: Website.ID) -> Website? {
        websites.first { $0.id == id }
    }

    var sortedWebsites: [Website] {
        guard sortOrder == .visitors, let ranking = visitorRanking else { return websites }
        let order = Dictionary(uniqueKeysWithValues: ranking.enumerated().map { ($1, $0) })
        return websites.sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
    }

    func isFavorite(_ id: Website.ID) -> Bool {
        favoriteIDs.contains(id)
    }

    func toggleFavorite(_ website: Website) {
        if let index = favoriteIDs.firstIndex(of: website.id) {
            favoriteIDs.remove(at: index)
        } else {
            favoriteIDs.append(website.id)
        }
        FavoritesStore.set(favoriteIDs, for: account.id)
        didChange()
    }

    /// Loads the websites; `force` (pull to refresh) also fetches fresh figures.
    func load(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        if force {
            await service.invalidate()
            figuresGeneration += 1
        }
        do {
            websites = try await service.websites(scope: scope)
            errorMessage = nil
            // Admins without websites of their own: show the whole instance instead.
            if !hasLoaded, websites.isEmpty, scope == .mine, canSeeAllWebsites {
                scope = .all
                return
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        hasLoaded = true
        if sortOrder == .visitors { await rankByVisitors() }
    }

    /// The figures and line of a list row, for the current period.
    func loadFigures(for website: Website) async {
        let period = period
        let generation = figuresGeneration
        guard rowGenerations[website.id] != generation || rowStats[website.id] == nil || rowSeries[website.id] == nil else { return }
        let selection = DateSelection.preset(period)
        let interval = selection.interval
        let unit = selection.unit
        let service = service
        async let stats = try? service.stats(websiteID: website.id, interval: interval)
        async let traffic = try? service.traffic(websiteID: website.id, interval: interval, unit: unit)
        let (loadedStats, loadedTraffic) = await (stats, traffic)
        // The user may have picked another period meanwhile.
        guard period == self.period else { return }
        if let loadedStats { rowStats[website.id] = loadedStats }
        if let loadedTraffic { rowSeries[website.id] = loadedTraffic.filled(in: interval, unit: unit).visitors }
        if loadedStats != nil, loadedTraffic != nil { rowGenerations[website.id] = generation }
    }

    private func rankByVisitors() async {
        let period = period
        let interval = period.interval()
        let service = service
        let missing = websites.filter { rowStats[$0.id] == nil || rowGenerations[$0.id] != figuresGeneration }
        let loaded = await withTaskGroup(of: (Website.ID, WebsiteStats?).self) { group in
            for website in missing {
                group.addTask { (website.id, try? await service.stats(websiteID: website.id, interval: interval)) }
            }
            var results: [(Website.ID, WebsiteStats?)] = []
            for await result in group { results.append(result) }
            return results
        }
        guard period == self.period else { return }
        for (id, stats) in loaded {
            if let stats { rowStats[id] = stats }
        }
        let ranking = websites
            .sorted { (rowStats[$0.id]?.current.visitors ?? -1) > (rowStats[$1.id]?.current.visitors ?? -1) }
            .map(\.id)
        withAnimation(.smooth) { visitorRanking = ranking }
    }

    // MARK: Mutations

    @discardableResult
    func create(name: String, domain: String, teamID: String?) async throws -> Website {
        let website = try await service.createWebsite(name: name, domain: domain, teamID: teamID)
        websites.append(website)
        websites.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        didChange()
        return website
    }

    func update(_ website: Website, name: String, domain: String) async throws {
        var updated = try await service.updateWebsite(id: website.id, name: name, domain: domain)
        // Keep relations the update response doesn't include.
        updated.team = updated.team ?? website.team
        if let index = websites.firstIndex(where: { $0.id == website.id }) {
            websites[index] = updated
        }
        didChange()
    }

    func delete(_ website: Website) async throws {
        try await service.deleteWebsite(id: website.id)
        websites.removeAll { $0.id == website.id }
        rowStats[website.id] = nil
        if isFavorite(website.id) { toggleFavorite(website) }
        didChange()
    }

    func reset(_ website: Website) async throws {
        try await service.resetWebsite(id: website.id)
        rowStats[website.id] = nil
        rowSeries[website.id] = nil
        rowGenerations[website.id] = nil
        didChange()
        await loadFigures(for: website)
    }

    private func didChange() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
