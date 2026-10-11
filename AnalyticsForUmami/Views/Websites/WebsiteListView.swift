import SwiftUI

struct WebsiteListView: View {
    @Binding var selection: Website.ID?

    @Environment(AppModel.self) private var model
    @Environment(WebsitesModel.self) private var websites
    @State private var searchText = ""
    @State private var isShowingNewWebsite = false
    @State private var websitePendingDeletion: Website?
    @State private var websiteBeingEdited: Website?
    @State private var websiteShowingCode: Website?

    private var canManage: Bool { websites.account.canManageWebsites }
    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var filteredWebsites: [Website] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let all = websites.sortedWebsites
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.name.localizedStandardContains(query) || ($0.domain?.localizedStandardContains(query) ?? false)
        }
    }

    var body: some View {
        @Bindable var websites = websites
        let all = filteredWebsites
        let pinned = isSearching ? [] : all.filter { websites.isFavorite($0.id) }
        let others = isSearching ? all : all.filter { !websites.isFavorite($0.id) }

        List(selection: $selection) {
            if websites.canSeeAllWebsites {
                Section {
                    Picker("Websites", selection: $websites.scope) {
                        Text("My websites").tag(WebsiteScope.mine)
                        Text("All (admin)").tag(WebsiteScope.all)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }

            if !pinned.isEmpty {
                Section {
                    rows(pinned)
                } header: {
                    sectionHeader("Pinned", showsPeriodMenu: true)
                }
            }

            if !others.isEmpty {
                Section {
                    rows(others)
                } header: {
                    sectionHeader(pinned.isEmpty ? nil : "Websites", showsPeriodMenu: pinned.isEmpty)
                } footer: {
                    if !isSearching {
                        Text("^[\(all.count) website](inflect: true)")
                    }
                }
            }
        }
        .animation(.smooth, value: pinned.map(\.id))
        .animation(.smooth, value: others.map(\.id))
        .overlay { overlay }
        .navigationTitle("Websites")
        .navigationSubtitle(websites.account.title)
        .searchable(text: $searchText, prompt: "Search websites")
        .refreshable { await websites.load(force: true) }
        .task { if !websites.hasLoaded { await websites.load() } }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Accounts", systemImage: "person.crop.circle") { model.isShowingAccounts.toggle() }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu("Sort", systemImage: "arrow.up.arrow.down") {
                    Picker("Sort by", selection: $websites.sortOrder) {
                        Label("Name", systemImage: "textformat").tag(WebsiteSortOrder.name)
                        Label("Visitors", systemImage: "person.2").tag(WebsiteSortOrder.visitors)
                    }
                }
            }
            if canManage {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add website", systemImage: "plus") { isShowingNewWebsite = true }
                }
            }
        }
        .sheet(isPresented: $isShowingNewWebsite) {
            WebsiteEditorView(mode: .create) { created in
                selection = created.id
            }
        }
        .sheet(item: $websiteBeingEdited) { website in
            WebsiteEditorView(mode: .edit(website))
        }
        .sheet(item: $websiteShowingCode) { website in
            NavigationStack { TrackingCodeView(website: website) }
        }
        .deleteWebsiteAlert($websitePendingDeletion) { deleted in
            if selection == deleted.id { selection = nil }
        }
    }

    /// Section title on the left, the period of the figures on the right: a
    /// menu to change it in the first section, a reminder in the second.
    private func sectionHeader(_ title: LocalizedStringKey?, showsPeriodMenu: Bool) -> some View {
        @Bindable var websites = websites
        return HStack {
            if let title { Text(title) }
            Spacer()
            if showsPeriodMenu {
                Menu {
                    Picker("Period", selection: $websites.period) {
                        ForEach(DateRangePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 3) {
                        Text(websites.period.title)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .contentShape(.rect)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel(Text("Period: \(websites.period.title)"))
            } else {
                Text(websites.period.title)
            }
        }
    }

    private func rows(_ list: [Website]) -> some View {
        ForEach(list) { website in
            let isFavorite = websites.isFavorite(website.id)
            NavigationLink(value: website.id) {
                WebsiteRow(website: website)
            }
            .swipeActions(edge: .leading) {
                Button(isFavorite ? "Unpin" : "Pin", systemImage: isFavorite ? "pin.slash.fill" : "pin.fill") {
                    websites.toggleFavorite(website)
                }
                .tint(.yellow)
            }
            .swipeActions(edge: .trailing) {
                if canManage {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        websitePendingDeletion = website
                    }
                    Button("Edit", systemImage: "pencil") {
                        websiteBeingEdited = website
                    }
                    .tint(.orange)
                }
            }
            .contextMenu {
                Button(isFavorite ? "Unpin" : "Pin", systemImage: isFavorite ? "pin.slash" : "pin") {
                    websites.toggleFavorite(website)
                }
                if canManage {
                    Button("Edit", systemImage: "pencil") { websiteBeingEdited = website }
                    Button("Tracking code", systemImage: "chevron.left.forwardslash.chevron.right") { websiteShowingCode = website }
                }
                if websites.account.kind != .demo, let domain = website.domain, let url = URL(string: "https://\(domain)") {
                    Link(destination: url) { Label("Open website", systemImage: "safari") }
                }
                if canManage {
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { websitePendingDeletion = website }
                }
            }
        }
    }

    @ViewBuilder
    private var overlay: some View {
        if websites.websites.isEmpty {
            if !websites.hasLoaded {
                ProgressView()
            } else if let error = websites.errorMessage {
                ContentUnavailableView {
                    Label("Couldn’t load websites", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { Task { await websites.load() } }
                        .buttonStyle(.bordered)
                }
            } else {
                ContentUnavailableView {
                    Label("No websites yet", systemImage: "globe")
                } description: {
                    Text("Add your first website to start collecting statistics.")
                } actions: {
                    if canManage {
                        Button("Add website") { isShowingNewWebsite = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        } else if filteredWebsites.isEmpty {
            ContentUnavailableView.search(text: searchText)
        }
    }

}

/// Stocks-style row: name and domain, today's line, visitors and change.
struct WebsiteRow: View {
    let website: Website
    @Environment(WebsitesModel.self) private var websites
    /// The line needs room: hidden in narrow columns (iPad sidebar) so the
    /// name stays readable.
    @State private var showsSparkline = true

    var body: some View {
        let stats = websites.rowStats[website.id]
        let change = stats.flatMap { Format.change($0.current.visitors, from: $0.previous?.visitors) }
        HStack(spacing: 12) {
            Monogram(text: website.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(website.name)
                    .font(.headline)
                    .lineLimit(1)
                if let domain = website.domain, !domain.isEmpty, domain != website.name {
                    Text(domain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsSparkline {
                let series = websites.rowSeries[website.id]
                TrendSparkline(points: series ?? [], domain: websites.chartDomain,
                               color: Trend(change).color(), lineWidth: 1.5, showsFill: false)
                    .frame(width: 52, height: 28)
                    // Charts would animate the line out of nothing: fade it in instead.
                    .transaction { $0.animation = nil }
                    .opacity(series == nil ? 0 : 1)
                    .animation(.easeOut(duration: 0.25), value: series == nil)
            }

            VStack(alignment: .trailing, spacing: 3) {
                Group {
                    if let stats {
                        RollingNumber(text: Format.number(stats.current.visitors))
                    } else {
                        Text("0000")
                    }
                }
                .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                ChangePill(change: change, minWidth: 58)
            }
            .frame(minWidth: 62, alignment: .trailing)
            .redacted(reason: stats == nil ? .placeholder : [])
            .animation(.easeOut(duration: 0.25), value: stats == nil)
        }
        .padding(.vertical, 2)
        .onGeometryChange(for: Bool.self) { $0.size.width >= 330 } action: { showsSparkline = $0 }
        .accessibilityElement(children: .combine)
        .task(id: FiguresKey(website: website.id, period: websites.period, generation: websites.figuresGeneration)) {
            await websites.loadFigures(for: website)
        }
    }
}

/// Reloads a row's figures for another website, period or refresh.
private struct FiguresKey: Hashable {
    let website: Website.ID
    let period: DateRangePreset
    let generation: Int
}

/// Coloured initial, used instead of favicons so no third-party service learns
/// which domains the user tracks.
struct Monogram: View {
    let text: String
    var size: CGFloat = 36

    private var color: Color {
        let hash = text.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.55, brightness: 0.8)
    }

    var body: some View {
        Text(text.first.map { String($0).uppercased() } ?? "?")
            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .rect(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension Account.Kind {
    var systemImage: String {
        switch self {
        case .selfHosted: "server.rack"
        case .cloud: "cloud"
        case .share: "link"
        case .demo: "play.rectangle"
        }
    }
}
