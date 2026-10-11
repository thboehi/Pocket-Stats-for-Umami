import Foundation

/// What a breakdown widget shows: one ranking of one website. A single
/// request, which makes it the cheapest widget of the bundle.
struct BreakdownSnapshot: Hashable, Sendable {
    let accountID: UUID
    let websiteID: String
    let name: String
    let domain: String?
    let period: WidgetPeriod
    let type: MetricType
    let items: [MetricItem]

    var deepLink: DeepLink { .website(accountID: accountID, websiteID: websiteID) }

    static func load(account: Account, website: Website, period: WidgetPeriod,
                     type: MetricType, limit: Int) async throws -> BreakdownSnapshot {
        let service = AnalyticsServiceFactory.make(for: account)
        let items = try await service.metrics(websiteID: website.id, type: type,
                                              interval: period.preset.interval(), limit: limit)
        return BreakdownSnapshot(accountID: account.id, websiteID: website.id, name: website.name,
                                 domain: website.domain, period: period, type: type, items: items)
    }

    // MARK: Samples (widget gallery, previews)

    static func sample(type: MetricType = .path, period: WidgetPeriod = .today) -> BreakdownSnapshot {
        let values: [String] = switch type {
        case .path, .entry, .exit: ["/", "/trails/lac-bleu", "/blog/winter-gear", "/about", "/contact", "/shop", "/blog", "/faq"]
        case .title: ["Home", "Lac Bleu", "Winter gear", "About", "Contact", "Shop", "Blog", "FAQ"]
        case .referrer: ["google.com", "news.ycombinator.com", "", "mastodon.social", "reddit.com", "bing.com", "duckduckgo.com", "x.com"]
        case .country: ["CH", "FR", "DE", "US", "IT", "GB", "AT", "BE"]
        case .city: ["Lausanne", "Genève", "Zürich", "Paris", "Berlin", "Bern", "Lyon", "Milano"]
        case .browser: ["safari", "chrome", "firefox", "edge", "brave", "opera", "samsung", "crios"]
        case .device: ["mobile", "desktop", "tablet", "laptop"]
        case .os: ["iOS", "macOS", "Windows", "Android", "Linux", "Chrome OS"]
        case .language: ["fr", "de", "en", "it", "es"]
        case .screen: ["390x844", "1920x1080", "1440x900", "768x1024"]
        case .event: ["signup", "download", "contact", "share", "play", "subscribe"]
        }
        let items = values.enumerated().map { index, value in
            MetricItem(value: value, count: (1_019 * pow(0.68, Double(index))).rounded(),
                       country: type == .city ? ["CH", "CH", "CH", "FR", "DE", "CH", "FR", "IT"][min(index, 7)] : nil)
        }
        return BreakdownSnapshot(accountID: UUID(), websiteID: "sample", name: "Alpine Trails Blog",
                                 domain: "alpinetrails.example", period: period, type: type, items: items)
    }
}
