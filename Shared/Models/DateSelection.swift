import Foundation

/// Granularity of a time series, as understood by Umami's `unit` parameter.
enum TimeUnit: String, Sendable {
    case minute, hour, day, month

    var calendarComponent: Calendar.Component {
        switch self {
        case .minute: .minute
        case .hour: .hour
        case .day: .day
        case .month: .month
        }
    }
}

enum DateRangePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case today, last24Hours, yesterday, thisWeek, last7Days, thisMonth, last30Days, last90Days, thisYear, last12Months

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .today: "Today"
        case .last24Hours: "Last 24 hours"
        case .yesterday: "Yesterday"
        case .thisWeek: "This week"
        case .last7Days: "Last 7 days"
        case .thisMonth: "This month"
        case .last30Days: "Last 30 days"
        case .last90Days: "Last 90 days"
        case .thisYear: "This year"
        case .last12Months: "Last 12 months"
        }
    }

    func interval(now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        // Round up to the minute so that requests made within the same minute
        // are identical and can be shared (see CachingService).
        let now = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 60).rounded(.up) * 60)
        let startOfToday = calendar.startOfDay(for: now)
        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: startOfToday)! }

        switch self {
        case .today:
            return DateInterval(start: startOfToday, end: now)
        case .last24Hours:
            return DateInterval(start: now.addingTimeInterval(-86_400), end: now)
        case .yesterday:
            return DateInterval(start: daysAgo(1), end: startOfToday.addingTimeInterval(-1))
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
            return DateInterval(start: start, end: now)
        case .last7Days:
            return DateInterval(start: daysAgo(6), end: now)
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            return DateInterval(start: start, end: now)
        case .last30Days:
            return DateInterval(start: daysAgo(29), end: now)
        case .last90Days:
            return DateInterval(start: daysAgo(89), end: now)
        case .thisYear:
            let start = calendar.dateInterval(of: .year, for: now)?.start ?? startOfToday
            return DateInterval(start: start, end: now)
        case .last12Months:
            let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            let start = calendar.date(byAdding: .month, value: -11, to: thisMonth)!
            return DateInterval(start: start, end: now)
        }
    }
}

/// The period the user is looking at: a relative preset (re-evaluated on every
/// refresh) or a fixed custom interval.
enum DateSelection: Hashable, Sendable {
    case preset(DateRangePreset)
    case custom(DateInterval)

    var interval: DateInterval {
        switch self {
        case .preset(let preset): preset.interval()
        case .custom(let interval): interval
        }
    }

    var unit: TimeUnit {
        let days = interval.duration / 86_400
        if days <= 2 { return .hour }
        if days <= 95 { return .day }
        return .month
    }

    /// The stretch just before `interval`, shifted by whole days (or months)
    /// so the chart buckets line up: today is compared with yesterday at the
    /// same hours, the last 7 days with the 7 days before.
    static func previous(of interval: DateInterval, unit: TimeUnit, calendar: Calendar = .current) -> DateInterval {
        let component: Calendar.Component = unit == .month ? .month : .day
        let length: TimeInterval = unit == .month ? 30.44 * 86_400 : 86_400
        // A little slack for daylight saving days (23 or 25 hours).
        let count = max(Int((interval.duration / length - 0.05).rounded(.up)), 1)
        guard let start = calendar.date(byAdding: component, value: -count, to: interval.start),
              let end = calendar.date(byAdding: component, value: -count, to: interval.end),
              end > start else {
            return DateInterval(start: interval.start.addingTimeInterval(-interval.duration), duration: interval.duration)
        }
        return DateInterval(start: start, end: end)
    }

    var title: String {
        switch self {
        case .preset(let preset):
            return String(localized: preset.title)
        case .custom(let interval):
            let style = Date.FormatStyle(date: .abbreviated, time: .omitted)
            return "\(interval.start.formatted(style)) – \(interval.end.formatted(style))"
        }
    }
}
