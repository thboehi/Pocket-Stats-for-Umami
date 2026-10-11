import SwiftUI

/// One website: the headline figure and its curve, who is online, then the
/// other metrics. This screen draws a chart, so it asks for the series the
/// list never needed.
struct WatchWebsiteDetail: View {
    let website: Website

    @Environment(WatchModel.self) private var model
    @State private var snapshot: WebsiteSnapshot?
    @State private var errorMessage: String?

    private var trendColor: Color {
        Trend(snapshot?.change).color()
    }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                headline

                if let snapshot, !snapshot.series.isEmpty {
                    TrendSparkline(points: snapshot.series, baseline: snapshot.baseline,
                                   domain: snapshot.chartDomain, color: trendColor,
                                   showsTimeAxis: true, unit: snapshot.period.unit)
                        .frame(height: 56)
                }

                if let active = snapshot?.activeVisitors, active > 0 {
                    HStack(spacing: 4) {
                        LiveIndicator(count: active)
                        Text("online")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let snapshot {
                    Divider()
                    ForEach(WidgetMetric.allCases.filter { $0 != .visitors }, id: \.self) { metric in
                        WatchMetricRow(metric: metric, stats: snapshot.stats)
                    }
                }

                Picker(selection: $model.period) {
                    ForEach(WidgetPeriod.allCases, id: \.self) { period in
                        Text(period.localizedTitle).tag(period)
                    }
                } label: {
                    Text("Period")
                }
                .pickerStyle(.navigationLink)
                .padding(.top, 2)
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle(website.name)
        #if DEBUG
        .defaultScrollAnchor(WatchDebugLaunch.scrollAnchor)
        #endif
        .task(id: taskID) { await load() }
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(snapshot?.headline ?? "—")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: snapshot?.value ?? 0))
            Spacer(minLength: 0)
            if snapshot?.change != nil {
                ChangePill(change: snapshot?.change, minWidth: 0,
                           font: .system(size: 12, weight: .semibold, design: .rounded))
            }
        }
        .redacted(reason: snapshot == nil && errorMessage == nil ? .placeholder : [])
    }

    /// The screen reloads when the period changes, and when the iPhone sends
    /// an account that is no longer the one this website belongs to.
    private var taskID: String {
        "\(model.account?.id.uuidString ?? "")|\(model.period.rawValue)"
    }

    private func load() async {
        guard let account = model.account else { return }
        errorMessage = nil
        do {
            snapshot = try await WebsiteSnapshot.load(account: account, website: website, period: model.period)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// One line of the list under the chart: the metric, its figure, and how it
/// moved against the previous period.
struct WatchMetricRow: View {
    let metric: WidgetMetric
    let stats: WebsiteStats

    private var value: Double { metric.value(stats.current) }
    private var change: Double? {
        stats.previous.flatMap { Format.change(value, from: metric.value($0)) }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(metric.shortTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(metric.format(value))
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
            if let change {
                Text(Format.signedPercent(change))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Trend(change).color(higherIsBetter: metric.higherIsBetter))
                    .frame(minWidth: 38, alignment: .trailing)
            }
        }
    }
}
