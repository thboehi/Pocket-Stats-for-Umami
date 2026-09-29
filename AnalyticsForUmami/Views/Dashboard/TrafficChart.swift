import Charts
import SwiftUI

/// Views and visitors per time bucket, overlaid like on the Umami web dashboard,
/// with the visitors of the previous period as a dashed line.
struct TrafficChart: View {
    let series: TrafficSeries?
    var previous: TrafficSeries?
    let unit: TimeUnit

    @State private var selectedDate: Date?

    private var buckets: [(date: Date, views: Double, visitors: Double)] {
        guard let series else { return [] }
        let visitorsByDate = Dictionary(series.visitors.map { ($0.date, $0.value) }, uniquingKeysWith: +)
        return series.pageviews.map { ($0.date, $0.value, visitorsByDate[$0.date] ?? 0) }
    }

    /// Previous period's visitors, moved onto the current buckets (same index).
    private var previousPoints: [TimeSeriesPoint] {
        guard let series, let previous else { return [] }
        return zip(series.visitors, previous.visitors).map { TimeSeriesPoint(date: $0.date, value: $1.value) }
    }

    private var isEmpty: Bool {
        guard let series else { return false }
        return series.pageviews.allSatisfy { $0.value == 0 }
    }

    private var selectedPoint: (date: Date, views: Double, visitors: Double)? {
        guard let selectedDate, let series else { return nil }
        let calendar = Calendar.current
        func matches(_ point: TimeSeriesPoint) -> Bool {
            calendar.isDate(point.date, equalTo: selectedDate, toGranularity: unit.calendarComponent)
        }
        guard let views = series.pageviews.first(where: matches) else { return nil }
        let visitors = series.visitors.first(where: matches)?.value ?? 0
        return (views.date, views.value, visitors)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The selected bucket's values replace the legend, so they never
            // need room outside the list row (which clips its content).
            ZStack(alignment: .leading) {
                if let selectedPoint {
                    SelectionSummary(date: selectedPoint.date, unit: unit, views: selectedPoint.views, visitors: selectedPoint.visitors)
                } else {
                    HStack(spacing: 16) {
                        LegendItem(color: .accentColor, title: "Visitors")
                        LegendItem(color: .accentColor.opacity(0.35), title: "Views")
                        if !previousPoints.isEmpty {
                            PreviousLegendItem()
                        }
                    }
                }
            }
            .font(.caption)
            .frame(minHeight: 20, alignment: .leading)

            Chart {
                // Visitors are a subset of views: draw visitors from 0, then the
                // remaining views on top, so each bar reads like Umami's.
                ForEach(buckets, id: \.date) { bucket in
                    BarMark(
                        x: .value("Date", bucket.date, unit: unit.calendarComponent),
                        yStart: .value("Visitors", 0),
                        yEnd: .value("Visitors", bucket.visitors)
                    )
                    .foregroundStyle(Color.accentColor)
                    BarMark(
                        x: .value("Date", bucket.date, unit: unit.calendarComponent),
                        yStart: .value("Visitors", bucket.visitors),
                        yEnd: .value("Views", max(bucket.views, bucket.visitors))
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.35))
                }
                ForEach(previousPoints) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: unit.calendarComponent),
                        y: .value("Previous period", point.value),
                        series: .value("Series", "previous")
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.secondary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 3]))
                }
                if let selectedPoint {
                    RuleMark(x: .value("Date", selectedPoint.date, unit: unit.calendarComponent))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                        .zIndex(-1)
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Double.self) { Text(Format.number(number)) }
                    }
                }
            }
            .frame(height: 220)
            .overlay {
                if series == nil {
                    ProgressView()
                } else if isEmpty {
                    Text("No data for this period")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.default, value: series)
            .animation(.default, value: previous)
            // A bucket picked in another period would point at nothing.
            .onChange(of: unit) { selectedDate = nil }
        }
    }
}

private struct LegendItem: View {
    let color: Color
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(title).foregroundStyle(.secondary)
        }
    }
}

private struct PreviousLegendItem: View {
    var body: some View {
        HStack(spacing: 6) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 5))
                path.addLine(to: CGPoint(x: 14, y: 5))
            }
            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 3]))
            .frame(width: 14, height: 10)
            Text("Previous period").foregroundStyle(.secondary)
        }
    }
}

private struct SelectionSummary: View {
    let date: Date
    let unit: TimeUnit
    let views: Double
    let visitors: Double

    private var dateText: String {
        switch unit {
        case .minute, .hour: date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        case .day: date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .month: date.formatted(.dateTime.month(.wide).year())
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(dateText).fontWeight(.semibold)
            LegendItem(color: .accentColor, title: "Visitors: \(Format.number(visitors))")
            LegendItem(color: .accentColor.opacity(0.35), title: "Views: \(Format.number(views))")
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}
