import Charts
import SwiftUI
import WidgetKit

/// Big number of a widget, in the rounded digits of the Stocks widgets.
private struct HeadlineNumber: View {
    let value: Double
    var size: CGFloat

    var body: some View {
        Text(Format.number(value))
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: value))
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
                .widgetAccentable()
            if showsDomain, let domain = snapshot.domain, !domain.isEmpty, domain != snapshot.name {
                Text(domain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Single website

/// Small: name, line of the period, number of visitors and change.
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
            TrendSparkline(points: snapshot.visitors, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                           color: Trend(snapshot.change).color)
                .padding(.vertical, 8)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                HeadlineNumber(value: snapshot.stats.current.visitors, size: 26)
                Spacer(minLength: 0)
                ChangePill(change: snapshot.change, minWidth: 0)
            }
            PeriodLabel(period: snapshot.period, widgetKey: widgetKey)
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
                HeadlineNumber(value: snapshot.stats.current.visitors, size: 30)
                PeriodLabel(period: snapshot.period, widgetKey: widgetKey)
                    .padding(.bottom, 6)
                HStack(spacing: 8) {
                    ChangePill(change: snapshot.change, minWidth: 0)
                    LiveIndicator(count: snapshot.activeVisitors)
                }
            }
            .frame(width: 138, alignment: .leading)

            VStack(spacing: 8) {
                TrendSparkline(points: snapshot.visitors, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                               color: Trend(snapshot.change).color, showsTimeAxis: true, unit: snapshot.period.unit)
                HStack(spacing: 6) {
                    WidgetFigure(title: "Views", value: Format.number(snapshot.stats.current.pageviews))
                    WidgetFigure(title: "Visits", value: Format.number(snapshot.stats.current.visits))
                    WidgetFigure(title: "Bounce", value: Format.percent(snapshot.stats.current.bounceRate))
                }
            }
        }
    }
}

/// Large: header, big chart, six key figures and the top pages.
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
                HeadlineNumber(value: current.visitors, size: 34)
                ChangePill(change: snapshot.change, minWidth: 0)
                Spacer(minLength: 0)
                PeriodLabel(period: snapshot.period, widgetKey: widgetKey)
            }
            .padding(.top, 8)

            TrendSparkline(points: snapshot.visitors, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                           color: Trend(snapshot.change).color, showsTimeAxis: true, unit: snapshot.period.unit)
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

            if !snapshot.topPages.isEmpty {
                Divider().padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(snapshot.topPages.prefix(3)) { page in
                        HStack {
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
        }
    }
}

// MARK: - Several websites

/// One line of the watchlist: name, line of the period, visitors and change.
struct WatchlistRow: View {
    let snapshot: WebsiteSnapshot
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            // Three rows fit a medium widget only without the domains.
            SiteTitle(snapshot: snapshot, nameFont: .system(size: compact ? 13 : 14, weight: .bold), showsDomain: !compact)
                .frame(maxWidth: .infinity, alignment: .leading)
            TrendSparkline(points: snapshot.visitors, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                           color: Trend(snapshot.change).color, lineWidth: 1.5, showsFill: false)
                .frame(width: 52)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.number(snapshot.stats.current.visitors))
                    .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                ChangePill(change: snapshot.change, minWidth: 54, font: .system(size: 11, weight: .semibold, design: .rounded))
            }
            .frame(minWidth: 58, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

struct WatchlistWidgetView: View {
    let snapshots: [WebsiteSnapshot]
    let period: WidgetPeriod
    let maxRows: Int
    var widgetKey: String?

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
                Spacer()
                PeriodLabel(period: period, widgetKey: widgetKey)
            }
            .padding(.bottom, 4)

            let rows = Array(snapshots.prefix(maxRows))
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, snapshot in
                if index > 0 { Divider() }
                Link(destination: snapshot.deepLink.url) {
                    WatchlistRow(snapshot: snapshot, compact: maxRows <= 3)
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
                    Text(Format.number(snapshot.stats.current.visitors))
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
                TrendSparkline(points: snapshot.visitors, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                               color: .primary, lineWidth: 1.5)
            }
        }
    }
}

/// Ring filled by today's visitors compared to the previous period.
struct CircularWebsiteWidgetView: View {
    let snapshot: WebsiteSnapshot

    var body: some View {
        let current = snapshot.stats.current.visitors
        let target = max(snapshot.stats.previous?.visitors ?? current, 1)
        Gauge(value: min(current, target), in: 0...target) {
            LogoMark()
        } currentValueLabel: {
            Text(Format.number(current))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel(Text("^[\(Int(current)) visitor](inflect: true)"))
    }
}

struct InlineWebsiteWidgetView: View {
    let snapshot: WebsiteSnapshot

    var body: some View {
        let visitors = Format.number(snapshot.stats.current.visitors)
        if let active = snapshot.activeVisitors, active > 0 {
            Label("\(visitors) visitors · \(active) online", systemImage: Trend(snapshot.change).systemImage)
        } else {
            Label("\(visitors) visitors · \(snapshot.name)", systemImage: Trend(snapshot.change).systemImage)
        }
    }
}

// MARK: - Shortcuts

/// Card shown by Siri and Shortcuts under the spoken answer.
struct VisitorsSnippetView: View {
    let snapshot: WebsiteSnapshot

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                SiteTitle(snapshot: snapshot)
                HeadlineNumber(value: snapshot.stats.current.visitors, size: 30)
                HStack(spacing: 8) {
                    ChangePill(change: snapshot.change, minWidth: 0)
                    PeriodLabel(period: snapshot.period)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TrendSparkline(points: snapshot.visitors, baseline: snapshot.baseline, domain: snapshot.chartDomain,
                           color: Trend(snapshot.change).color)
                .frame(width: 130, height: 70)
        }
        .padding()
    }
}
