import SwiftUI

struct StatsGrid: View {
    let stats: WebsiteStats?

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 3 : 2)
        LazyVGrid(columns: columns, spacing: 12) {
            let current = stats?.current
            let previous = stats?.previous
            StatTile(title: "Visitors", value: current.map { Format.number($0.visitors) },
                     change: current.flatMap { Format.change($0.visitors, from: previous?.visitors) })
            StatTile(title: "Visits", value: current.map { Format.number($0.visits) },
                     change: current.flatMap { Format.change($0.visits, from: previous?.visits) })
            StatTile(title: "Views", value: current.map { Format.number($0.pageviews) },
                     change: current.flatMap { Format.change($0.pageviews, from: previous?.pageviews) })
            StatTile(title: "Views per visit",
                     value: current.map { ($0.visits > 0 ? $0.pageviews / $0.visits : 0).formatted(.number.precision(.fractionLength(1))) },
                     change: current.flatMap { current in
                         previous.flatMap { previous in
                             Format.change(current.visits > 0 ? current.pageviews / current.visits : 0,
                                           from: previous.visits > 0 ? previous.pageviews / previous.visits : nil)
                         }
                     })
            StatTile(title: "Bounce rate", value: current.map { Format.percent($0.bounceRate) },
                     change: current.flatMap { Format.change($0.bounceRate, from: previous?.bounceRate) },
                     lowerIsBetter: true)
            StatTile(title: "Visit duration", value: current.map { Format.duration($0.averageVisitDuration) },
                     change: current.flatMap { Format.change($0.averageVisitDuration, from: previous?.averageVisitDuration) })
        }
    }
}

struct StatTile: View {
    let title: LocalizedStringKey
    let value: String?
    let change: Double?
    var lowerIsBetter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Group {
                if let value {
                    RollingNumber(text: value)
                } else {
                    Text("0000")
                        .redacted(reason: .placeholder)
                }
            }
            .font(.system(.title, design: .rounded).weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            ChangeBadge(change: change, lowerIsBetter: lowerIsBetter)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct ChangeBadge: View {
    let change: Double?
    var lowerIsBetter = false

    var body: some View {
        if let change, change.isFinite, abs(change) >= 0.005 {
            let isGood = (change > 0) != lowerIsBetter
            Label(Format.signedPercent(change), systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isGood ? .green : .red)
                .labelStyle(.titleAndIcon)
                .accessibilityLabel(Text("\(Format.signedPercent(change)) compared to the previous period"))
        } else {
            Text(change == nil ? " " : "=")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}
