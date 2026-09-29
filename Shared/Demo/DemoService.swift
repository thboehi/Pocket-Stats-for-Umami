import Foundation

/// Offline sample data. Used for App Review (no server needed) and for users who
/// want to explore before connecting their instance. Numbers are deterministic
/// for a given site and hour, so totals, charts and breakdowns stay consistent.
struct DemoService: AnalyticsService {
    let account: Account

    func websites(scope: WebsiteScope) async throws -> [Website] {
        try await simulateLatency()
        return await DemoStore.shared.websites
    }

    func teams() async throws -> [TeamSummary] {
        [TeamSummary(id: "demo-team", name: String(localized: "Marketing"))]
    }

    func createWebsite(name: String, domain: String, teamID: String?) async throws -> Website {
        try await simulateLatency()
        let website = Website(id: UUID().uuidString.lowercased(), name: name, domain: domain, teamId: teamID, createdAt: .now)
        await DemoStore.shared.upsert(website)
        return website
    }

    func updateWebsite(id: String, name: String, domain: String) async throws -> Website {
        try await simulateLatency()
        guard var website = await DemoStore.shared.websites.first(where: { $0.id == id }) else { throw UmamiError.notFound }
        website.name = name
        website.domain = domain
        await DemoStore.shared.upsert(website)
        return website
    }

    func deleteWebsite(id: String) async throws {
        try await simulateLatency()
        await DemoStore.shared.remove(id: id)
    }

    func resetWebsite(id: String) async throws {
        try await simulateLatency()
    }

    func stats(websiteID: String, interval: DateInterval) async throws -> WebsiteStats {
        try await simulateLatency()
        // Compared with the same hours the day before for periods shorter than a
        // day ("Today"), otherwise with the period just before.
        let shift = max(interval.duration, 86_400)
        let previous = DateInterval(start: interval.start.addingTimeInterval(-shift), duration: interval.duration)
        return WebsiteStats(
            current: values(websiteID, visitors: visitors(websiteID, in: interval)),
            previous: values(websiteID, visitors: visitors(websiteID, in: previous))
        )
    }

    func traffic(websiteID: String, interval: DateInterval, unit: TimeUnit) async throws -> TrafficSeries {
        try await simulateLatency()
        let calendar = Calendar.current
        var visitorPoints: [TimeSeriesPoint] = []
        var viewPoints: [TimeSeriesPoint] = []
        var cursor = calendar.dateInterval(of: unit.calendarComponent, for: interval.start)?.start ?? interval.start
        while cursor < interval.end {
            let next = calendar.date(byAdding: unit.calendarComponent, value: 1, to: cursor)!
            let bucket = DateInterval(start: max(cursor, interval.start), end: min(next, interval.end))
            let count = visitors(websiteID, in: bucket).rounded()
            visitorPoints.append(TimeSeriesPoint(date: cursor, value: count))
            viewPoints.append(TimeSeriesPoint(date: cursor, value: (count * pagesPerVisitor(websiteID)).rounded()))
            cursor = next
        }
        return TrafficSeries(pageviews: viewPoints, visitors: visitorPoints)
    }

    func metrics(websiteID: String, type: MetricType, interval: DateInterval, limit: Int) async throws -> [MetricItem] {
        try await simulateLatency()
        let factor = switch type {
        case .path, .title: pagesPerVisitor(websiteID)
        case .event: 0.12
        default: 1.0
        }
        let total = visitors(websiteID, in: interval) * factor
        let items = DemoCatalog.breakdown(for: type)
        let weightSum = items.reduce(0) { $0 + $1.weight }
        return items.prefix(limit).compactMap { item in
            let count = (total * item.weight / weightSum).rounded()
            return count > 0 ? MetricItem(value: item.value, count: count, country: item.country) : nil
        }
    }

    func activeVisitors(websiteID: String) async throws -> Int {
        let now = Date.now
        let hourly = hourlyVisitors(websiteID, hour: Calendar.current.dateInterval(of: .hour, for: now)!.start)
        let minuteNoise = DemoRandom.value(seed(websiteID) &+ UInt64(now.timeIntervalSince1970 / 60))
        // Never empty: the demo should always look alive, even at night.
        return max(1 + Int(minuteNoise * 4), Int((hourly / 5) * (0.6 + minuteNoise)))
    }

    // MARK: - Generation

    private func simulateLatency() async throws {
        try await Task.sleep(for: .milliseconds(Int.random(in: 120...350)))
    }

    private func values(_ websiteID: String, visitors: Double) -> WebsiteStats.Values {
        let visits = visitors * 1.28
        return WebsiteStats.Values(
            pageviews: (visitors * pagesPerVisitor(websiteID)).rounded(),
            visitors: visitors.rounded(),
            visits: visits.rounded(),
            bounces: (visits * 0.41).rounded(),
            totaltime: (visits * 104).rounded()
        )
    }

    private func pagesPerVisitor(_ websiteID: String) -> Double {
        1.8 + DemoRandom.value(seed(websiteID)) * 1.4
    }

    /// Sum of hourly visitors over the interval (partial hours are prorated).
    private func visitors(_ websiteID: String, in interval: DateInterval) -> Double {
        let calendar = Calendar.current
        let end = min(interval.end, .now)
        guard end > interval.start else { return 0 }
        var cursor = calendar.dateInterval(of: .hour, for: interval.start)!.start
        var total = 0.0
        while cursor < end {
            let next = cursor.addingTimeInterval(3600)
            let overlap = min(next, end).timeIntervalSince(max(cursor, interval.start))
            if overlap > 0 { total += hourlyVisitors(websiteID, hour: cursor) * overlap / 3600 }
            cursor = next
        }
        return total
    }

    private static let hourCurve: [Double] = [
        0.25, 0.15, 0.1, 0.08, 0.1, 0.2, 0.45, 0.8, 1.1, 1.3, 1.4, 1.45,
        1.35, 1.4, 1.45, 1.4, 1.3, 1.2, 1.15, 1.2, 1.1, 0.9, 0.65, 0.4,
    ]

    private func hourlyVisitors(_ websiteID: String, hour: Date) -> Double {
        let calendar = Calendar.current
        let daily = DemoStore.dailyBase(websiteID)
        let dayIndex = Double(Int(hour.timeIntervalSince1970 / 86_400))
        let today = Double(Int(Date.now.timeIntervalSince1970 / 86_400))
        let weekday = calendar.component(.weekday, from: hour)
        let weekendFactor = (weekday == 1 || weekday == 7) ? 0.7 : 1.0
        // Steady growth up to today (a slow decline for one website), whatever
        // the date: the demo always tells a plausible story.
        let trend = exp(DemoStore.dailyGrowth(websiteID) * (dayIndex - today)) * (1 + 0.05 * sin(dayIndex / 3))
        let noise = 0.75 + 0.5 * DemoRandom.value(seed(websiteID) &+ UInt64(hour.timeIntervalSince1970 / 3600))
        let curve = Self.hourCurve[calendar.component(.hour, from: hour)] / 24
        return max(0, daily * weekendFactor * trend * noise * curve)
    }

    private func seed(_ websiteID: String) -> UInt64 {
        websiteID.unicodeScalars.reduce(1469598103934665603) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
    }
}

// MARK: - Store

actor DemoStore {
    static let shared = DemoStore()

    private(set) var websites: [Website] = [
        Website(id: "demo-bakery", name: "Boulangerie du Lac", domain: "boulangerie-du-lac.example", shareId: "demoShare1", createdAt: .now.addingTimeInterval(-86_400 * 400)),
        Website(id: "demo-blog", name: "Alpine Trails Blog", domain: "alpinetrails.example", createdAt: .now.addingTimeInterval(-86_400 * 800)),
        Website(id: "demo-shop", name: "Swiss Watch Shop", domain: "shop.swisswatch.example", teamId: "demo-team", createdAt: .now.addingTimeInterval(-86_400 * 200), team: TeamSummary(id: "demo-team", name: "Marketing")),
        Website(id: "demo-portfolio", name: "Portfolio", domain: "jane-design.example", createdAt: .now.addingTimeInterval(-86_400 * 90)),
    ]

    func upsert(_ website: Website) {
        if let index = websites.firstIndex(where: { $0.id == website.id }) {
            websites[index] = website
        } else {
            websites.append(website)
            websites.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    func remove(id: String) {
        websites.removeAll { $0.id == id }
    }

    /// Relative change per day.
    nonisolated static func dailyGrowth(_ websiteID: String) -> Double {
        switch websiteID {
        case "demo-bakery": 0.009
        case "demo-blog": 0.012
        case "demo-shop": 0.014
        case "demo-portfolio": -0.004
        default: 0.005
        }
    }

    nonisolated static func dailyBase(_ websiteID: String) -> Double {
        switch websiteID {
        case "demo-bakery": 180
        case "demo-blog": 1_250
        case "demo-shop": 3_400
        case "demo-portfolio": 45
        default: 20
        }
    }
}

enum DemoRandom {
    /// SplitMix64 mapped to 0..<1.
    static func value(_ seed: UInt64) -> Double {
        var z = seed &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
}

enum DemoCatalog {
    struct Entry {
        let value: String?
        let weight: Double
        var country: String? = nil
    }

    static func breakdown(for type: MetricType) -> [Entry] {
        switch type {
        case .path, .entry:
            [.init(value: "/", weight: 40), .init(value: "/products", weight: 18), .init(value: "/blog/spring-hike", weight: 12),
             .init(value: "/about", weight: 8), .init(value: "/contact", weight: 6), .init(value: "/blog", weight: 5),
             .init(value: "/pricing", weight: 4), .init(value: "/fr", weight: 3), .init(value: "/de", weight: 2)]
        case .exit:
            [.init(value: "/contact", weight: 25), .init(value: "/", weight: 22), .init(value: "/products", weight: 15),
             .init(value: "/blog/spring-hike", weight: 10), .init(value: "/about", weight: 6)]
        case .title:
            [.init(value: "Home", weight: 40), .init(value: "Products", weight: 18), .init(value: "A spring hike above the lake", weight: 12),
             .init(value: "About us", weight: 8), .init(value: "Contact", weight: 6)]
        case .referrer:
            [.init(value: "google.com", weight: 45), .init(value: nil, weight: 25), .init(value: "instagram.com", weight: 10),
             .init(value: "duckduckgo.com", weight: 6), .init(value: "linkedin.com", weight: 5), .init(value: "news.ycombinator.com", weight: 3),
             .init(value: "bing.com", weight: 3)]
        case .browser:
            [.init(value: "chrome", weight: 48), .init(value: "ios", weight: 24), .init(value: "safari", weight: 10),
             .init(value: "firefox", weight: 8), .init(value: "edge-chromium", weight: 6), .init(value: "samsung", weight: 2)]
        case .os:
            [.init(value: "iOS", weight: 34), .init(value: "Windows 10", weight: 26), .init(value: "Mac OS", weight: 20),
             .init(value: "Android OS", weight: 14), .init(value: "Linux", weight: 4)]
        case .device:
            [.init(value: "mobile", weight: 52), .init(value: "desktop", weight: 30), .init(value: "laptop", weight: 14), .init(value: "tablet", weight: 4)]
        case .country:
            [.init(value: "CH", weight: 46), .init(value: "FR", weight: 15), .init(value: "DE", weight: 12), .init(value: "US", weight: 9),
             .init(value: "IT", weight: 6), .init(value: "GB", weight: 4), .init(value: "AT", weight: 3), .init(value: "BE", weight: 2)]
        case .city:
            [.init(value: "Zurich", weight: 20, country: "CH"), .init(value: "Geneva", weight: 14, country: "CH"),
             .init(value: "Lausanne", weight: 12, country: "CH"), .init(value: "Paris", weight: 9, country: "FR"),
             .init(value: "Berlin", weight: 6, country: "DE"), .init(value: "Bern", weight: 5, country: "CH")]
        case .language:
            [.init(value: "fr", weight: 35), .init(value: "de", weight: 30), .init(value: "en", weight: 25), .init(value: "it", weight: 8)]
        case .screen:
            [.init(value: "390x844", weight: 30), .init(value: "1920x1080", weight: 25), .init(value: "1440x900", weight: 15), .init(value: "393x852", weight: 12)]
        case .event:
            [.init(value: "newsletter-signup", weight: 3), .init(value: "add-to-cart", weight: 2.4), .init(value: "contact-form", weight: 1.2),
             .init(value: "outbound-link", weight: 0.9)]
        }
    }
}
