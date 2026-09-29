import Foundation

/// Websites pinned at the top of the list, per account. Stored in the App Group
/// so the widgets list them first too.
enum FavoritesStore {
    private static func key(_ accountID: UUID) -> String { "favorites.\(accountID.uuidString)" }

    static func ids(for accountID: UUID) -> [String] {
        AppGroup.defaults.stringArray(forKey: key(accountID)) ?? []
    }

    static func set(_ ids: [String], for accountID: UUID) {
        AppGroup.defaults.set(ids.isEmpty ? nil : ids, forKey: key(accountID))
    }

    static func removeAll(for accountID: UUID) {
        set([], for: accountID)
    }
}

/// Period picked with the button of a widget, which overrides the configured one
/// until the configuration changes.
enum WidgetPeriodStore {
    private static let key = "widget.periods"

    private static var stored: [String: [String: String]] {
        get { AppGroup.defaults.dictionary(forKey: key) as? [String: [String: String]] ?? [:] }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }

    /// The period to show for the widget identified by `widgetKey`.
    static func period(for widgetKey: String, configured: WidgetPeriod) -> WidgetPeriod {
        guard let entry = stored[widgetKey], entry["base"] == configured.rawValue,
              let value = entry["value"].flatMap(WidgetPeriod.init(rawValue:)) else {
            stored[widgetKey] = ["base": configured.rawValue]
            return configured
        }
        return value
    }

    static func cycle(_ widgetKey: String) {
        var entry = stored[widgetKey] ?? [:]
        let current = (entry["value"] ?? entry["base"]).flatMap(WidgetPeriod.init(rawValue:)) ?? .today
        entry["value"] = current.next.rawValue
        stored[widgetKey] = entry
    }
}
