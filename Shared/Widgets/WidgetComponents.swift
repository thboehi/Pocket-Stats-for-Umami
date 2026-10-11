import AppIntents
import Charts
import SwiftUI
import WidgetKit

/// Direction of a change, coloured like the Stocks app.
enum Trend {
    case up, down, flat

    init(_ change: Double?) {
        guard let change, change.isFinite, abs(change) >= 0.005 else {
            self = .flat
            return
        }
        self = change > 0 ? .up : .down
    }

    /// Green when the move is good, red when it is bad. A rising bounce rate is
    /// bad, hence `higherIsBetter`.
    func color(higherIsBetter: Bool = true) -> Color {
        switch self {
        case .up: higherIsBetter ? .positive : .negative
        case .down: higherIsBetter ? .negative : .positive
        case .flat: .muted
        }
    }

    var systemImage: String {
        switch self {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "equal"
        }
    }
}

/// Stocks-style line: filled with a fading gradient, dashed line at the
/// previous period's average.
struct TrendSparkline: View {
    let points: [TimeSeriesPoint]
    var baseline: Double?
    var domain: ClosedRange<Date>?
    var color: Color
    var lineWidth: CGFloat = 2
    var showsFill = true
    var showsTimeAxis = false
    var unit: TimeUnit = .hour
    /// Set when the curve is not the headline metric, so the widget never
    /// passes off one series for another.
    var legend: LocalizedStringResource?

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var maxValue: Double {
        max(points.map(\.value).max() ?? 0, baseline ?? 0, 1) * 1.08
    }

    var body: some View {
        Chart {
            if let baseline {
                RuleMark(y: .value("Previous period", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.7))
            }
            ForEach(points) { point in
                if showsFill {
                    AreaMark(x: .value("Time", point.date), y: .value("Visitors", point.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(colors: [color.opacity(renderingMode == .fullColor ? 0.32 : 0.45), color.opacity(0)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
                LineMark(x: .value("Time", point.date), y: .value("Visitors", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .chartYScale(domain: 0...maxValue)
        .chartXScale(domain: domain ?? (points.first?.date ?? .now)...(points.last?.date ?? .now))
        .chartYAxis(.hidden)
        .chartXAxis {
            if showsTimeAxis {
                AxisMarks(values: .automatic(desiredCount: unit == .hour ? 4 : 3)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(unit == .hour ? date.formatted(.dateTime.hour()) : date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .overlay(alignment: .topTrailing) {
            if let legend {
                Text(legend)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }
}

/// White percentage on a green or red rounded rectangle, like the Stocks app.
///
/// Tinted Home Screens (`.accented`) and the Lock Screen (`.vibrant`) flatten
/// every fill into a single colour: the pill and its white text would land on
/// the same colour and read as an empty white block. Outside `.fullColor` the
/// badge drops its background and shows the direction with an arrow instead.
struct ChangePill: View {
    let change: Double?
    var higherIsBetter = true
    var minWidth: CGFloat = 56
    var font: Font = .system(size: 12, weight: .semibold, design: .rounded)

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var trend: Trend { Trend(change) }

    private var label: String {
        guard let change else { return "–" }
        return trend == .flat ? "0 %" : Format.signedPercent(change)
    }

    var body: some View {
        Group {
            if renderingMode == .fullColor {
                Text(label)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .frame(minWidth: minWidth, alignment: .trailing)
                    .background(trend.color(higherIsBetter: higherIsBetter), in: .rect(cornerRadius: 5, style: .continuous))
            } else {
                HStack(spacing: 1) {
                    if change != nil {
                        Image(systemName: trend.systemImage)
                            .font(font.weight(.bold))
                            .imageScale(.small)
                    }
                    Text(label)
                }
                .padding(.vertical, 2.5)
                .frame(minWidth: minWidth, alignment: .trailing)
            }
        }
        .font(font)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityLabel(Text(change.map { "\(Format.signedPercent($0)) compared to the previous period" } ?? ""))
    }
}

/// Green dot and the number of visitors online.
struct LiveIndicator: View {
    let count: Int?

    var body: some View {
        if let count {
            HStack(spacing: 4) {
                Circle()
                    .fill(count > 0 ? Color.positive : Color.secondary.opacity(0.6))
                    .frame(width: 6, height: 6)
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("^[\(count) visitor](inflect: true) online"))
        }
    }
}

/// What a widget shows instead of figures: no account yet, no website, or the
/// server did not answer.
struct WidgetMessageView: View {
    let systemImage: String
    let text: Text

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            text
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

/// "Visitors · Today ⌃⌄": a button that switches the period when the widget
/// supports it, plain text otherwise.
struct PeriodLabel: View {
    let period: WidgetPeriod
    /// `nil` prints the period alone.
    var metric: WidgetMetric? = .visitors
    var widgetKey: String?

    var body: some View {
        if let widgetKey {
            Button(intent: CycleWidgetPeriodIntent(widgetKey: widgetKey)) { label(interactive: true) }
                .buttonStyle(.plain)
        } else {
            label(interactive: false)
        }
    }

    private func label(interactive: Bool) -> some View {
        HStack(spacing: 3) {
            if let metric {
                Text("\(Text(metric.shortTitle)) · \(Text(period.shortTitle))")
            } else {
                Text(period.shortTitle)
            }
            if interactive {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .contentShape(.rect)
    }
}

/// A compact figure with its caption, for the stats rows of the bigger widgets.
struct WidgetFigure: View {
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The configured list at the bottom of the large widget: top pages,
/// referrers, countries… Each row carries a bar for its share of the total.
struct BreakdownList: View {
    let type: MetricType
    let items: [MetricItem]
    var rowCount = 3
    /// Small families have no room for the header line.
    var compact = false

    private var rows: [MetricItem] { Array(items.prefix(rowCount)) }
    private var maxCount: Double { max(rows.map(\.count).max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            if !compact {
                HStack {
                    Text(type.title)
                    Spacer(minLength: 8)
                    Text(type.countLabel)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            }

            ForEach(rows) { item in
                HStack(spacing: 6) {
                    if let symbol = type.leadingSymbol(for: item) {
                        Text(symbol).font(.system(size: 11))
                    }
                    Text(type.displayName(for: item))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(Format.number(item.count))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: compact ? 11 : 12, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(alignment: .leading) {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.secondary.opacity(0.16))
                            .frame(width: max(proxy.size.width * item.count / maxCount, 3))
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
