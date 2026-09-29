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

    var color: Color {
        switch self {
        case .up: Color(.systemGreen)
        case .down: Color(.systemRed)
        case .flat: Color(.systemGray)
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
        .accessibilityHidden(true)
    }
}

/// White percentage on a green or red rounded rectangle, like the Stocks app.
struct ChangePill: View {
    let change: Double?
    var minWidth: CGFloat = 56
    var font: Font = .system(size: 12, weight: .semibold, design: .rounded)

    var body: some View {
        let trend = Trend(change)
        Text(change.map { Trend($0) == .flat ? "0 %" : Format.signedPercent($0) } ?? "–")
            .font(font)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .frame(minWidth: minWidth, alignment: .trailing)
            .background(trend.color, in: .rect(cornerRadius: 5, style: .continuous))
            .widgetAccentable()
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
                    .fill(count > 0 ? Color(.systemGreen) : Color.secondary.opacity(0.6))
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

/// "Visitors · Today ⌃⌄": a button that switches the period when the widget
/// supports it, plain text otherwise.
struct PeriodLabel: View {
    let period: WidgetPeriod
    var widgetKey: String?
    var showsMetric = true

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
            if showsMetric {
                Text("Visitors · \(Text(period.shortTitle))")
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
