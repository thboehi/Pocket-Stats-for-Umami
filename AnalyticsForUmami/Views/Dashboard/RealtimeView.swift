import SwiftUI

/// Live view: active visitors plus what happened in the last 30 minutes,
/// refreshed every 10 seconds while on screen.
struct RealtimeView: View {
    let website: Website

    @Environment(WebsitesModel.self) private var websites
    @State private var active: Int?
    @State private var breakdowns: [MetricType: [MetricItem]] = [:]
    @State private var lastUpdate: Date?
    @State private var errorMessage: String?

    private let types: [MetricType] = [.path, .referrer, .country, .event]
    private static let window: TimeInterval = 30 * 60

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle((active ?? 0) > 0 ? .green : .secondary)
                            .symbolEffect(.pulse, isActive: (active ?? 0) > 0)
                        Group {
                            if let active {
                                RollingNumber(text: "\(active)")
                            } else {
                                Text(verbatim: "–")
                            }
                        }
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    }
                    Text("Visitors right now")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if let lastUpdate {
                        Text("Updated \(lastUpdate.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            ForEach(types) { type in
                Section {
                    let items = breakdowns[type] ?? []
                    if items.isEmpty {
                        Text("Nothing in the last 30 minutes")
                            .foregroundStyle(.secondary)
                    } else {
                        let maxCount = items.map(\.count).max() ?? 1
                        ForEach(items) { item in
                            MetricRow(type: type, item: item, fraction: item.count / maxCount, total: nil)
                        }
                    }
                } header: {
                    Text(type.title)
                }
            }
        }
        .navigationTitle("Realtime")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func refresh() async {
        let interval = DateInterval(start: .now.addingTimeInterval(-Self.window), end: .now)
        // Straight to the server: every refresh asks for a new 30-minute window,
        // which the cache would only pile up.
        let service = websites.service.base
        let websiteID = website.id
        do {
            let count = try await service.activeVisitors(websiteID: websiteID)
            var loaded: [MetricType: [MetricItem]] = [:]
            try await withThrowingTaskGroup(of: (MetricType, [MetricItem]).self) { group in
                for type in types {
                    group.addTask { (type, try await service.metrics(websiteID: websiteID, type: type, interval: interval, limit: 8)) }
                }
                for try await (type, items) in group {
                    loaded[type] = items
                }
            }
            withAnimation {
                active = count
                breakdowns = loaded
            }
            lastUpdate = .now
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
