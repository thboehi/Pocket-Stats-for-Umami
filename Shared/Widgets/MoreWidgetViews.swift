import Charts
import SwiftUI
import WidgetKit

// MARK: - Breakdown

/// A ranking on its own: top pages, referrers, countries… The number of rows
/// follows the family, the bars the share of the biggest one.
struct BreakdownWidgetView: View {
    let snapshot: BreakdownSnapshot
    var rowCount: Int
    var compact = false
    var widgetKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.name)
                        .font(.system(size: compact ? 13 : 15, weight: .bold))
                        .lineLimit(1)
                    if !compact, let domain = snapshot.domain, !domain.isEmpty, domain != snapshot.name {
                        Text(domain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 2)
                Image(systemName: snapshot.type.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 6)

            if snapshot.items.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing in this period.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                BreakdownList(type: snapshot.type, items: snapshot.items, rowCount: rowCount, compact: compact)
                Spacer(minLength: 0)
            }

            PeriodLabel(period: snapshot.period, metric: nil, widgetKey: widgetKey)
                .padding(.top, 4)
        }
    }
}

// MARK: - Live

/// Big count of who is on the site right now, over the history the widget has
/// collected itself.
struct LiveWidgetView: View {
    let snapshot: LiveSnapshot
    var showsPages = false

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(snapshot.activeVisitors > 0 && renderingMode == .fullColor
                                     ? Color.positive : Color.secondary)
                Text(snapshot.name)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(snapshot.activeVisitors)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(value: Double(snapshot.activeVisitors)))
                    .widgetAccentable()
                Text("online")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.top, 2)

            if snapshot.history.count >= 3 {
                LiveSparkline(points: snapshot.history)
                    .widgetAccentable()
                    .frame(height: showsPages ? 30 : 42)
                    .padding(.top, 4)
            }

            if showsPages, !snapshot.pages.isEmpty {
                Divider().padding(.vertical, 6)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(snapshot.pages.prefix(3)) { page in
                        HStack(spacing: 6) {
                            Text(page.value ?? "/")
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Text(Format.number(page.count))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                }
            }

            Spacer(minLength: 0)
            if let window = footerWindow {
                Text("Last \(window)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The pages come from a fixed half hour; the bars cover whatever the
    /// reload budget allowed, so the caption says which one it is talking about.
    private var footerWindow: String? {
        if showsPages, !snapshot.pages.isEmpty {
            return Format.duration(LiveSnapshot.pageWindow)
        }
        guard let first = snapshot.history.first?.date, let last = snapshot.history.last?.date,
              last.timeIntervalSince(first) >= 60 else { return nil }
        return Duration.seconds(last.timeIntervalSince(first))
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow, maximumUnitCount: 1))
    }
}

/// Bars rather than a line: the samples are spaced by whatever the reload
/// budget allowed, and bars never pretend to know what happened in between.
struct LiveSparkline: View {
    let points: [TimeSeriesPoint]

    var body: some View {
        Chart(Array(points.enumerated()), id: \.offset) { index, point in
            BarMark(x: .value("Sample", index), y: .value("Online", point.value))
                .foregroundStyle(Color.accentColor)
                .cornerRadius(1.5)
        }
        .chartYScale(domain: 0...max(points.map(\.value).max() ?? 1, 1) * 1.1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }
}

struct RectangularLiveWidgetView: View {
    let snapshot: LiveSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(snapshot.name)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .widgetAccentable()
                Text("^[\(snapshot.activeVisitors) visitor](inflect: true) online")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if snapshot.history.count >= 3 {
                LiveSparkline(points: snapshot.history)
                    .frame(width: 44)
            }
        }
    }
}

// MARK: - Total

/// Every website of an account added up.
struct TotalWidgetView: View {
    let snapshot: TotalSnapshot
    var showsChart = false
    var widgetKey: String?

    private var trendColor: Color {
        Trend(snapshot.change).color(higherIsBetter: snapshot.metric.higherIsBetter)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                LogoMark()
                    .frame(width: 11, height: 12)
                    .foregroundStyle(Color.accentColor)
                Text(snapshot.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("^[\(snapshot.sites.count) website](inflect: true)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if showsChart {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 4)
                        headline(size: 30)
                        PeriodLabel(period: snapshot.period, metric: snapshot.metric, widgetKey: widgetKey)
                        if snapshot.comparing {
                            ChangePill(change: snapshot.change, higherIsBetter: snapshot.metric.higherIsBetter, minWidth: 0)
                                .padding(.top, 6)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: 130, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        TrendSparkline(points: snapshot.series, baseline: snapshot.baseline,
                                       domain: snapshot.chartDomain, color: trendColor,
                                       showsTimeAxis: true, unit: snapshot.period.unit)
                            .widgetAccentable()
                        ForEach(snapshot.sites.prefix(2)) { site in
                            HStack(spacing: 6) {
                                Text(site.name).lineLimit(1)
                                Spacer(minLength: 8)
                                Text(snapshot.metric.format(site.value))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                    }
                }
            } else {
                Spacer(minLength: 4)
                headline(size: 32)
                HStack(spacing: 6) {
                    if snapshot.comparing {
                        ChangePill(change: snapshot.change, higherIsBetter: snapshot.metric.higherIsBetter, minWidth: 0)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
                Spacer(minLength: 0)
                PeriodLabel(period: snapshot.period, metric: snapshot.metric, widgetKey: widgetKey)
            }
        }
    }

    private func headline(size: CGFloat) -> some View {
        Text(snapshot.headline)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: snapshot.value))
            .widgetAccentable()
    }
}
