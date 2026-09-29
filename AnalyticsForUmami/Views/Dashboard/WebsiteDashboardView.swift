import SwiftUI

struct WebsiteDashboardView: View {
    let website: Website

    @Environment(WebsitesModel.self) private var websites
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("dashboard.preset") private var preset = DateRangePreset.last7Days
    @State private var customInterval: DateInterval?

    @State private var model: DashboardModel?

    @State private var isShowingCustomRange = false
    @State private var isEditing = false
    @State private var isShowingCode = false
    @State private var isShowingRealtime = false
    @State private var isConfirmingReset = false
    @State private var websitePendingDeletion: Website?
    @State private var actionError: String?

    private var selection: DateSelection {
        customInterval.map(DateSelection.custom) ?? .preset(preset)
    }

    /// Metric types shown first in each section, fetched as soon as the dashboard opens.
    private static let sections: [(title: LocalizedStringResource, types: [MetricType])] = [
        ("Pages", [.path, .entry, .exit, .title]),
        ("Sources", [.referrer]),
        ("Location", [.country, .city, .language]),
        ("Environment", [.browser, .os, .device]),
        ("Events", [.event]),
    ]

    var body: some View {
        ScrollViewReader { proxy in
            dashboard
            #if DEBUG
                .task { await applyDebugScreen(proxy) }
            #endif
        }
    }

    #if DEBUG
    private func applyDebugScreen(_ proxy: ScrollViewProxy) async {
        for period in DebugLaunch.dashboardPeriods {
            try? await Task.sleep(for: .seconds(4))
            customInterval = nil
            preset = period
        }
        guard let screen = DebugLaunch.screen else { return }
        try? await Task.sleep(for: .seconds(1))
        switch screen {
        case "sections": withAnimation { proxy.scrollTo("traffic", anchor: .top) }
        case "realtime": isShowingRealtime = true
        case "code": isShowingCode = true
        case "edit": isEditing = true
        default: break
        }
    }
    #endif

    private var dashboard: some View {
        List {
            Section {
                LiveVisitorsRow(website: website) { isShowingRealtime = true }
            }

            if let errorMessage = model?.errorMessage, model?.stats == nil {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Try Again") { Task { await load(force: true) } }
                }
            }

            Section {
                StatsGrid(stats: model?.stats)
                    .opacity(isShowingPreviousPeriod ? 0.45 : 1)
                    .animation(.easeOut(duration: 0.2), value: isShowingPreviousPeriod)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                periodMenu
                    .font(.headline)
                    .textCase(nil)
            }

            Section {
                TrafficChart(series: model?.traffic, previous: model?.previousTraffic, unit: model?.trafficUnit ?? selection.unit)
                    .opacity(isShowingPreviousPeriod ? 0.45 : 1)
                    .animation(.easeOut(duration: 0.2), value: isShowingPreviousPeriod)
                    .padding(.vertical, 8)
            } header: {
                Text("Traffic")
            }
            .id("traffic")

            if let model {
                ForEach(Self.sections, id: \.types) { section in
                    MetricSection(title: section.title, types: section.types, model: model, selection: selection)
                }
            }
        }
        .navigationTitle(website.name)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await load(force: true) }
        .task { select(selection) }
        .onChange(of: selection) { _, newValue in select(newValue) }
        // Back from the background: fresh numbers without pulling to refresh.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
        .task { QuickActions.recordVisit(to: website, account: websites.account, accounts: appModel.accounts) }
        // Opened from the realtime control, a quick action or Shortcuts.
        .task(id: appModel.pendingRealtimeWebsiteID) {
            guard appModel.pendingRealtimeWebsiteID == website.id else { return }
            appModel.pendingRealtimeWebsiteID = nil
            isShowingRealtime = true
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { actionsMenu }
        }
        .navigationDestination(isPresented: $isShowingRealtime) {
            RealtimeView(website: website)
        }
        .sheet(isPresented: $isShowingCustomRange) {
            CustomRangeView(initial: selection.interval) { customInterval = $0 }
        }
        .sheet(isPresented: $isEditing) {
            WebsiteEditorView(mode: .edit(website))
        }
        .sheet(isPresented: $isShowingCode) {
            NavigationStack { TrackingCodeView(website: website) }
        }
        .confirmationDialog("Reset statistics?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Reset statistics", role: .destructive, action: reset)
        } message: {
            Text("All data collected for “\(website.name)” will be permanently erased. The website and its tracking code are kept.")
        }
        .deleteWebsiteAlert($websitePendingDeletion)
        .alert("Something went wrong", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: Toolbar

    private var periodMenu: some View {
        Menu {
            Picker("Period", selection: Binding<DateRangePreset?>(
                get: { customInterval == nil ? preset : nil },
                set: { newValue in
                    if let newValue {
                        preset = newValue
                        customInterval = nil
                    }
                }
            )) {
                ForEach(DateRangePreset.allCases) { preset in
                    Text(preset.title).tag(Optional(preset))
                }
            }
            Divider()
            Button("Custom range…", systemImage: "calendar") { isShowingCustomRange = true }
        } label: {
            HStack(spacing: 4) {
                Text(selection.title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
            }
        }
        .accessibilityLabel(Text("Period: \(selection.title)"))
    }

    private var actionsMenu: some View {
        Menu("More", systemImage: "ellipsis") {
            Button("Realtime", systemImage: "dot.radiowaves.left.and.right") { isShowingRealtime = true }
            if account.canManageWebsites {
                Button("Tracking code", systemImage: "chevron.left.forwardslash.chevron.right") { isShowingCode = true }
                Button("Edit website", systemImage: "pencil") { isEditing = true }
            }
            if let url = umamiURL {
                Link(destination: url) {
                    Label("Open in Umami", systemImage: "arrow.up.forward.app")
                }
            }
            if account.kind != .demo, let domain = website.domain, !domain.isEmpty, let url = URL(string: "https://\(domain)") {
                Link(destination: url) { Label("Open website", systemImage: "safari") }
            }
            if account.canManageWebsites {
                Divider()
                Button("Reset statistics", systemImage: "arrow.counterclockwise", role: .destructive) { isConfirmingReset = true }
                Button("Delete website", systemImage: "trash", role: .destructive) { websitePendingDeletion = website }
            }
        }
    }

    private var account: Account { websites.account }

    private var isShowingPreviousPeriod: Bool { model?.isShowingPreviousPeriod ?? false }

    /// This website in the Umami web app (the public share page for share links).
    private var umamiURL: URL? {
        switch account.kind {
        case .demo: nil
        case .cloud: Account.cloudWebURL.appending(path: "websites").appending(path: website.id)
        case .selfHosted: account.dashboardURL(for: website.id)
        case .share: account.shareID.map(account.shareURL(for:))
        }
    }

    // MARK: Loading

    private var dashboardModel: DashboardModel {
        if let model { return model }
        let model = DashboardModel(website: website, service: websites.service)
        self.model = model
        return model
    }

    private static var firstMetricTypes: [MetricType] { sections.map { $0.types[0] } }

    /// Loads another period, right away.
    private func select(_ selection: DateSelection) {
        dashboardModel.select(selection, metricTypes: Self.firstMetricTypes)
    }

    /// Reloads the current period (pull to refresh, retry, after a reset).
    private func load(force: Bool = false) async {
        await dashboardModel.load(selection, metricTypes: Self.firstMetricTypes, force: force)
    }

    private func reset() {
        Task {
            do {
                try await websites.reset(website)
                await load(force: true)
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
}

// MARK: - Live visitors

struct LiveVisitorsRow: View {
    let website: Website
    let action: () -> Void

    @Environment(WebsitesModel.self) private var websites
    @State private var count: Int?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle((count ?? 0) > 0 ? .green : .secondary)
                    .symbolEffect(.pulse, isActive: (count ?? 0) > 0)
                if let count {
                    Text("^[\(count) visitor](inflect: true) online")
                        .contentTransition(.numericText())
                } else {
                    Text("Checking live visitors…")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .task {
            // Refresh every 30 seconds while the dashboard is visible.
            while !Task.isCancelled {
                if let value = try? await websites.service.activeVisitors(websiteID: website.id) {
                    withAnimation { count = value }
                }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}

// MARK: - Custom range

struct CustomRangeView: View {
    let onApply: (DateInterval) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date

    init(initial: DateInterval, onApply: @escaping (DateInterval) -> Void) {
        self.onApply = onApply
        _start = State(initialValue: initial.start)
        _end = State(initialValue: min(initial.end, .now))
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Start", selection: $start, in: ...end, displayedComponents: .date)
                DatePicker("End", selection: $end, in: start...Date.now, displayedComponents: .date)
            }
            .navigationTitle("Custom range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        let calendar = Calendar.current
                        let startOfDay = calendar.startOfDay(for: start)
                        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!.addingTimeInterval(-1)
                        onApply(DateInterval(start: startOfDay, end: min(endOfDay, .now)))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
