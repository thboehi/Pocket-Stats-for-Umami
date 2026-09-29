import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        #if DEBUG
        if DebugLaunch.screen == "widgets" {
            WidgetGalleryView()
        } else if DebugLaunch.screen == "home" {
            HomeScreenMockView()
        } else {
            content
        }
        #else
        content
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if let account = model.currentAccount {
            AccountsDrawer {
                MainSplitView(account: account)
                    // Fresh state (list, selection, caches) for every account.
                    .id(account.id)
            }
        } else {
            WelcomeView()
        }
    }
}

/// Sidebar (websites) + detail (dashboard). Collapses to a stack on iPhone.
struct MainSplitView: View {
    @Environment(AppModel.self) private var model
    @State private var websites: WebsitesModel
    @State private var selectedWebsiteID: Website.ID?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(account: Account) {
        _websites = State(initialValue: WebsitesModel(service: AnalyticsServiceFactory.make(for: account)))
    }

    var body: some View {
        NavigationSplitView {
            WebsiteListView(selection: $selectedWebsiteID)
        } detail: {
            NavigationStack {
                if let id = selectedWebsiteID, let website = websites.website(id: id) {
                    WebsiteDashboardView(website: website)
                        .id(website.id)
                } else {
                    ContentUnavailableView(
                        "Select a website",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Choose a website in the list to see its statistics.")
                    )
                }
            }
        }
        .environment(websites)
        .onChange(of: selectedWebsiteID == nil || horizontalSizeClass == .regular, initial: true) { _, isAtRoot in
            model.canOpenAccountsFromEdge = isAtRoot
        }
        .task(id: model.pendingWebsiteID) {
            guard let id = model.pendingWebsiteID else { return }
            model.pendingWebsiteID = nil
            selectedWebsiteID = id
        }
        .onChange(of: websites.websites) {
            // Leave the dashboard of a website that was just deleted.
            if let id = selectedWebsiteID, websites.website(id: id) == nil {
                selectedWebsiteID = nil
            }
        }
    }
}
