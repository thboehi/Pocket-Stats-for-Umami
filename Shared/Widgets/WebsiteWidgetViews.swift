import Charts
import SwiftUI
import WidgetKit

/// Big number of a widget, in the rounded digits of the Stocks widgets.
/// `value` only drives the rolling transition; `text` is what is printed, so a
/// duration or a percentage reads correctly.
private struct HeadlineNumber: View {
    let text: String
    let value: Double
    var size: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: value))
            .widgetAccentable()
    }
}

private struct SiteTitle: View {
    let snapshot: WebsiteSnapshot
    var nameFont: Font = .system(size: 15, weight: .bold)
    var showsDomain = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(snapshot.name)
                .font(nameFont)
                .lineLimit(1)
            if showsDomain, let domain = snapshot.domain, !domain.isEmpty, domain != snapshot.name {
                Text(domain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

extension WebsiteSnapshot {
    /// Colour of the curve and of the change badge, red when the move is bad.
    var trendColor: Color {
        Trend(change).color(higherIsBetter: metric.higherIsBetter)
    }

    /// Set when the curve shows another series than the headline figure.
    var chartLegend: LocalizedStringResource? {
        metric.chartsItself ? nil : metric.chartedMetric.shortTitle
    }
}

// MARK: - Single website

/// Small: name, line of the period, the chosen figure and its change.
struct SmallWebsiteWidgetView: View {
    let snapshot: WebsiteSnapshot
    var widgetKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                SiteTitle(snapshot: snapshot)
                Spacer(minLength: 0)
                LiveIndicator(count: snapshot.activeVisitors)
            }
            TrendSparkline(points: snapshot.series, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                           color: snapshot.trendColor)
                .widgetAccentable()
                .padding(.vertical, 8)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                HeadlineNumber(text: snapshot.headline, value: snapshot.value, size: 26)
                Spacer(minLength: 0)
                if snapshot.comparing {
                    ChangePill(change: snapshot.change, higherIsBetter: snapshot.metric.higherIsBetter, minWidth: 0)
                }
            }
            PeriodLabel(period: snapshot.period, metric: snapshot.metric, widgetKey: widgetKey)
                .padding(.top, 1)
        }
    }
}

/// Medium: the small layout on the left, a bigger chart with its time axis and
/// three key figures on the right.
struct MediumWebsiteWidgetView: View {
    let snapshot: WebsiteSnapshot
    var widgetKey: String?

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                SiteTitle(snapshot: snapshot)
                Spacer(minLength: 6)
                HeadlineNumber(text: snapshot.headline, value: snapshot.value, size: 30)
                PeriodLabel(period: snapshot.period, metric: snapshot.metric, widgetKey: widgetKey)
                    .padding(.bottom, 6)
                HStack(spacing: 8) {
                    if snapshot.comparing {
                        ChangePill(change: snapshot.change, higherIsBetter: snapshot.metric.higherIsBetter, minWidth: 0)
                    }
                    LiveIndicator(count: snapshot.activeVisitors)
                }
            }
            .frame(width: 138, alignment: .leading)

            VStack(spacing: 8) {
                TrendSparkline(points: snapshot.series, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                               color: snapshot.trendColor, showsTimeAxis: true, unit: snapshot.period.unit,
                               legend: snapshot.chartLegend)
                    .widgetAccentable()
                HStack(spacing: 6) {
                    WidgetFigure(title: "Views", value: Format.number(snapshot.stats.current.pageviews))
                    WidgetFigure(title: "Visits", value: Format.number(snapshot.stats.current.visits))
                    WidgetFigure(title: "Bounce", value: Format.percent(snapshot.stats.current.bounceRate))
                }
            }
        }
    }
}

/// Large: header, big chart, six key figures and the configured breakdown.
struct LargeWebsiteWidgetView: View {
    let snapshot: WebsiteSnapshot
    var widgetKey: String?

    var body: some View {
        let current = snapshot.stats.current
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SiteTitle(snapshot: snapshot, nameFont: .system(size: 17, weight: .bold))
                Spacer(minLength: 4)
                LiveIndicator(count: snapshot.activeVisitors)
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                HeadlineNumber(text: snapshot.headline, value: snapshot.value, size: 34)
                if snapshot.comparing {
                    ChangePill(change: snapshot.change, higherIsBetter: snapshot.metric.higherIsBetter, minWidth: 0)
                }
                Spacer(minLength: 0)
                PeriodLabel(period: snapshot.period, metric: snapshot.metric, widgetKey: widgetKey)
            }
            .padding(.top, 8)

            TrendSparkline(points: snapshot.series, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                           color: snapshot.trendColor, showsTimeAxis: true, unit: snapshot.period.unit,
                           legend: snapshot.chartLegend)
                .widgetAccentable()
                .frame(maxHeight: .infinity)
                .padding(.vertical, 10)

            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    WidgetFigure(title: "Views", value: Format.number(current.pageviews))
                    WidgetFigure(title: "Visits", value: Format.number(current.visits))
                    WidgetFigure(title: "Views per visit",
                                 value: (current.visits > 0 ? current.pageviews / current.visits : 0).formatted(.number.precision(.fractionLength(1))))
                }
                GridRow {
                    WidgetFigure(title: "Bounce rate", value: Format.percent(current.bounceRate))
                    WidgetFigure(title: "Visit duration", value: Format.duration(current.averageVisitDuration))
                    WidgetFigure(title: "Online", value: snapshot.activeVisitors.map { "\($0)" } ?? "–")
                }
            }

            if let type = snapshot.breakdownType, !snapshot.breakdown.isEmpty {
                Divider().padding(.vertical, 8)
                BreakdownList(type: type, items: snapshot.breakdown)
            }
        }
    }
}

// MARK: - Several websites

/// One line of the watchlist: name, curve, the chosen figure and its change.
struct WatchlistRow: View {
    let snapshot: WebsiteSnapshot
    var compact = false
    var showsSparkline = true

    var body: some View {
        HStack(spacing: 10) {
            // Three rows fit a medium widget only without the domains.
            SiteTitle(snapshot: snapshot, nameFont: .system(size: compact ? 13 : 14, weight: .bold), showsDomain: !compact)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showsSparkline {
                TrendSparkline(points: snapshot.series, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                               color: snapshot.trendColor, lineWidth: 1.5, showsFill: false)
                    .widgetAccentable()
                    .frame(width: 52)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(snapshot.headline)
                    .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
                if snapshot.comparing {
                    ChangePill(change: snapshot.change, higherIsBetter: snapshot.metric.higherIsBetter,
                               minWidth: showsSparkline ? 54 : 0,
                               font: .system(size: 11, weight: .semibold, design: .rounded))
                }
            }
            .frame(minWidth: showsSparkline ? 58 : 0, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Home Screen only: it lays itself out from the widget family, and the system
/// families do not exist on watchOS.
#if os(iOS)
struct WatchlistWidgetView: View {
    let snapshots: [WebsiteSnapshot]
    let period: WidgetPeriod
    var metric: WidgetMetric = .visitors
    let maxRows: Int
    var widgetKey: String?
    var family: WidgetFamily = .systemMedium

    /// Domains and curves only fit the large widget, and only up to 7 rows.
    private var compact: Bool { family != .systemLarge || maxRows > 7 }
    private var showsSparkline: Bool { family != .systemSmall }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label {
                    Text("Websites")
                } icon: {
                    LogoMark()
                        .frame(width: 11, height: 12)
                        .foregroundStyle(Color.accentColor)
                }
                .font(.system(size: 13, weight: .bold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                if family != .systemSmall {
                    Spacer()
                    PeriodLabel(period: period, metric: metric, widgetKey: widgetKey)
                }
            }
            .padding(.bottom, 4)
            if family == .systemSmall {
                PeriodLabel(period: period, metric: metric, widgetKey: widgetKey)
                    .padding(.bottom, 4)
            }

            let rows = Array(snapshots.prefix(maxRows))
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, snapshot in
                if index > 0 { Divider() }
                Link(destination: snapshot.deepLink.url) {
                    WatchlistRow(snapshot: snapshot, compact: compact, showsSparkline: showsSparkline)
                        .frame(maxHeight: .infinity)
                        .foregroundStyle(Color.primary)
                }
            }
            if rows.count < maxRows {
                Spacer(minLength: 0)
            }
        }
    }
}

#endif

// MARK: - Lock Screen

struct RectangularWebsiteWidgetView: View {
    let snapshot: WebsiteSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(snapshot.name)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .widgetAccentable()
                Spacer(minLength: 2)
                if let change = snapshot.change {
                    Label(Format.signedPercent(change), systemImage: Trend(change).systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                        .imageScale(.small)
                }
            }
            HStack(alignment: .bottom, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.headline)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let active = snapshot.activeVisitors {
                        Text("\(active) online")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                TrendSparkline(points: snapshot.series, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                               color: .primary, lineWidth: 1.5)
            }
        }
    }
}

extension WebsiteSnapshot {
    /// What a gauge fills against: the same figure over the previous period,
    /// so a full ring means "already as good as last time".
    var gaugeTarget: Double {
        max(stats.previous.map { metric.value($0) } ?? value, value > 0 ? value : 1)
    }
}

/// Ring filled by the current figure compared to the previous period.
struct CircularWebsiteWidgetView: View {
    let snapshot: WebsiteSnapshot

    var body: some View {
        let target = snapshot.gaugeTarget
        Gauge(value: min(snapshot.value, target), in: 0...target) {
            LogoMark()
        } currentValueLabel: {
            Text(snapshot.headline)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel(Text(snapshot.headline))
    }
}

struct InlineWebsiteWidgetView: View {
    let snapshot: WebsiteSnapshot

    var body: some View {
        let figure = snapshot.headline
        if let active = snapshot.activeVisitors, active > 0 {
            Label("\(figure) \(Text(snapshot.metric.shortTitle)) · \(active) online", systemImage: Trend(snapshot.change).systemImage)
        } else {
            Label("\(figure) \(Text(snapshot.metric.shortTitle)) · \(snapshot.name)", systemImage: Trend(snapshot.change).systemImage)
        }
    }
}

#if os(watchOS)
/// A corner of a watch face: the figure in the corner itself, and the gauge of
/// the circular complication curved along the bezel. `.accessoryCorner` only
/// exists where there is a round screen to curve against.
struct CornerWebsiteWidgetView: View {
    let snapshot: WebsiteSnapshot

    var body: some View {
        let target = snapshot.gaugeTarget
        Text(snapshot.headline)
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .minimumScaleFactor(0.5)
            .widgetAccentable()
            .widgetLabel {
                Gauge(value: min(snapshot.value, target), in: 0...target) {
                    Text(snapshot.name)
                }
            }
            .accessibilityLabel(Text("\(snapshot.headline) \(Text(snapshot.metric.shortTitle)) · \(snapshot.name)"))
    }
}
#endif

// MARK: - Shortcuts

/// Card shown by Siri and Shortcuts under the spoken answer.
struct VisitorsSnippetView: View {
    let snapshot: WebsiteSnapshot

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                SiteTitle(snapshot: snapshot)
                HeadlineNumber(text: snapshot.headline, value: snapshot.value, size: 30)
                HStack(spacing: 8) {
                    ChangePill(change: snapshot.change, higherIsBetter: snapshot.metric.higherIsBetter, minWidth: 0)
                    PeriodLabel(period: snapshot.period, metric: snapshot.metric)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TrendSparkline(points: snapshot.series, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                           color: snapshot.trendColor)
                .frame(width: 130, height: 70)
        }
        .padding()
    }
}
