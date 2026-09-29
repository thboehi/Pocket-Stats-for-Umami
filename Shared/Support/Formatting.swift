import Foundation

enum Format {
    /// `1234` → `1,234`; `123456` → `123K` (locale aware).
    static func number(_ value: Double) -> String {
        if abs(value) >= 100_000 {
            return value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
        }
        return value.formatted(.number.precision(.fractionLength(0)))
    }

    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    /// `95` → `1m 35s`.
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 1 else { return "0s" }
        return Duration.seconds(Int(seconds.rounded()))
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow, maximumUnitCount: 2))
    }

    /// Relative change between two periods, `nil` when there is nothing to compare.
    static func change(_ current: Double, from previous: Double?) -> Double? {
        guard let previous, previous > 0 else { return nil }
        return (current - previous) / previous
    }

    static func signedPercent(_ change: Double) -> String {
        change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always(includingZero: false)))
    }

    static func flag(forRegionCode code: String?) -> String? {
        guard let code, code.count == 2 else { return nil }
        let scalars = code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }
        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }
}

extension MetricType {
    var title: LocalizedStringResource {
        switch self {
        case .path: "Pages"
        case .title: "Page titles"
        case .entry: "Entry pages"
        case .exit: "Exit pages"
        case .referrer: "Referrers"
        case .browser: "Browsers"
        case .os: "Operating systems"
        case .device: "Devices"
        case .country: "Countries"
        case .city: "Cities"
        case .language: "Languages"
        case .screen: "Screens"
        case .event: "Events"
        }
    }

    var shortTitle: LocalizedStringResource {
        switch self {
        case .path: "Path"
        case .title: "Title"
        case .entry: "Entry"
        case .exit: "Exit"
        case .referrer: "Referrers"
        case .browser: "Browser"
        case .os: "OS"
        case .device: "Device"
        case .country: "Country"
        case .city: "City"
        case .language: "Language"
        case .screen: "Screen"
        case .event: "Events"
        }
    }

    var systemImage: String {
        switch self {
        case .path, .entry, .exit, .title: "doc.text"
        case .referrer: "link"
        case .browser: "safari"
        case .os: "gearshape"
        case .device: "laptopcomputer.and.iphone"
        case .country, .city: "globe.europe.africa"
        case .language: "character.bubble"
        case .screen: "rectangle.dashed"
        case .event: "bolt"
        }
    }

    /// What the count means for this breakdown.
    var countLabel: LocalizedStringResource {
        switch self {
        case .path, .title: "Views"
        case .event: "Actions"
        default: "Visitors"
        }
    }

    func displayName(for item: MetricItem) -> String {
        guard let value = item.value, !value.isEmpty else {
            return switch self {
            case .referrer: String(localized: "Direct / none")
            default: String(localized: "Unknown")
            }
        }
        switch self {
        case .country:
            return Locale.current.localizedString(forRegionCode: value) ?? value
        case .language:
            return Locale.current.localizedString(forIdentifier: value)?.localizedCapitalized ?? value
        case .device:
            return switch value {
            case "desktop": String(localized: "Desktop")
            case "laptop": String(localized: "Laptop")
            case "mobile": String(localized: "Mobile")
            case "tablet": String(localized: "Tablet")
            default: value.capitalized
            }
        case .browser:
            return Self.browserNames[value] ?? value.capitalized
        default:
            return value
        }
    }

    func leadingSymbol(for item: MetricItem) -> String? {
        switch self {
        case .country: Format.flag(forRegionCode: item.value)
        case .city: Format.flag(forRegionCode: item.country)
        default: nil
        }
    }

    private static let browserNames: [String: String] = [
        "chrome": "Chrome", "crios": "Chrome (iOS)", "ios": "Safari (iOS)", "ios-webview": "iOS WebView",
        "safari": "Safari", "firefox": "Firefox", "fxios": "Firefox (iOS)", "edge": "Edge", "edge-chromium": "Edge",
        "edge-ios": "Edge (iOS)", "opera": "Opera", "samsung": "Samsung Internet", "instagram": "Instagram",
        "facebook": "Facebook", "android": "Android Browser", "chromium-webview": "Android WebView",
        "brave": "Brave", "yandexbrowser": "Yandex", "miui": "MIUI Browser", "silk": "Silk", "searchbot": "Bot",
    ]
}
