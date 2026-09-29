import AppIntents

/// Siri and Shortcuts phrases. Localized in `AppShortcuts.xcstrings`.
struct PocketStatsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetVisitorsIntent(),
            phrases: [
                "How many visitors on \(\.$website) in \(.applicationName)",
                "Visitors of \(\.$website) in \(.applicationName)",
                "How many visitors in \(.applicationName)",
                "\(.applicationName) visitors",
            ],
            shortTitle: "Visitors",
            systemImageName: "person.2"
        )
        AppShortcut(
            intent: OpenWebsiteIntent(),
            phrases: [
                "Open \(\.$website) in \(.applicationName)",
                "Show \(\.$website) in \(.applicationName)",
            ],
            shortTitle: "Open website",
            systemImageName: "chart.xyaxis.line"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .purple
}
