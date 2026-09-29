import SwiftUI

/// A dashboard section showing the top entries of one or more breakdowns
/// (e.g. Browsers / OS / Devices), switchable with a segmented control.
struct MetricSection: View {
    let title: LocalizedStringResource
    let types: [MetricType]
    let model: DashboardModel
    let selection: DateSelection

    @State private var type: MetricType

    init(title: LocalizedStringResource, types: [MetricType], model: DashboardModel, selection: DateSelection) {
        self.title = title
        self.types = types
        self.model = model
        self.selection = selection
        _type = State(initialValue: types[0])
    }

    var body: some View {
        Section {
            if types.count > 1 {
                Picker(String(localized: title), selection: $type) {
                    ForEach(types) { type in
                        Text(type.shortTitle).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
            }

            switch model.metrics[type] {
            case .loaded(let items) where items.isEmpty:
                Text("No data for this period")
                    .foregroundStyle(.secondary)
            case .loaded(let items):
                let maxCount = items.map(\.count).max() ?? 1
                ForEach(items.prefix(DashboardModel.previewCount)) { item in
                    MetricRow(type: type, item: item, fraction: item.count / maxCount, total: MetricRow.total(for: type, stats: model.stats))
                }
                if items.count > DashboardModel.previewCount {
                    NavigationLink {
                        MetricDetailView(type: type, website: model.website, selection: selection,
                                         interval: model.interval ?? selection.interval, stats: model.stats)
                    } label: {
                        Text("Show all")
                            .foregroundStyle(.tint)
                    }
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Try Again") { model.retryMetric(type) }
            case nil:
                ForEach(0..<3, id: \.self) { _ in
                    MetricRow(type: type, item: MetricItem(value: "Loading placeholder", count: 100), fraction: 0.5, total: nil)
                        .redacted(reason: .placeholder)
                }
            }
        } header: {
            Text(types.count > 1 ? title : types[0].title)
        }
        .animation(.default, value: model.metrics[type] == nil)
        // Other tabs of the section are fetched on demand; the model then
        // keeps them up to date when the period changes.
        .onChange(of: type, initial: true) { model.show(type) }
    }
}

struct MetricRow: View {
    let type: MetricType
    let item: MetricItem
    /// Bar length relative to the largest item.
    let fraction: Double
    /// Denominator for the percentage (total views or visitors of the period).
    let total: Double?

    static func total(for type: MetricType, stats: WebsiteStats?) -> Double? {
        guard let stats else { return nil }
        return switch type {
        case .path, .title: stats.current.pageviews
        case .entry, .exit: stats.current.visits
        case .event: nil
        default: stats.current.visitors
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let symbol = type.leadingSymbol(for: item) {
                    Text(symbol)
                }
                Text(type.displayName(for: item))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Text(Format.number(item.count))
                    .monospacedDigit()
                    .fontWeight(.medium)
                if let total, total > 0 {
                    Text(Format.percent(min(item.count / total, 1)))
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 36, alignment: .trailing)
                }
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.accentColor.opacity(0.25))
                    .frame(width: max(4, proxy.size.width * fraction))
            }
            .frame(height: 4)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Full list for one breakdown, with search.
struct MetricDetailView: View {
    let type: MetricType
    let website: Website
    let selection: DateSelection
    let interval: DateInterval
    let stats: WebsiteStats?

    @Environment(WebsitesModel.self) private var websites
    @State private var items: [MetricItem]?
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var filtered: [MetricItem] {
        guard let items else { return [] }
        guard !searchText.isEmpty else { return items }
        return items.filter { type.displayName(for: $0).localizedStandardContains(searchText) }
    }

    var body: some View {
        List {
            Section {
                let maxCount = items?.map(\.count).max() ?? 1
                ForEach(filtered) { item in
                    MetricRow(type: type, item: item, fraction: item.count / maxCount, total: MetricRow.total(for: type, stats: stats))
                        .contextMenu {
                            if let value = item.value {
                                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = value }
                            }
                        }
                }
            } header: {
                HStack {
                    Text(selection.title)
                    Spacer()
                    Text(type.countLabel)
                }
            }
        }
        .overlay {
            if items == nil && errorMessage == nil {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView("Couldn’t load data", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if items?.isEmpty == true {
                ContentUnavailableView("No data for this period", systemImage: type.systemImage)
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle(Text(type.title))
        .searchable(text: $searchText)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        do {
            items = try await websites.service.metrics(websiteID: website.id, type: type, interval: interval, limit: 500)
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
