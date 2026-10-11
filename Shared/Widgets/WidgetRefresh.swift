import Foundation
import WidgetKit

/// When a widget asks to be reloaded, and how much it deserves to be shown.
///
/// WidgetKit grants a widget roughly 40 to 70 reloads a day. Asking for one
/// every 15 minutes asks for 96 and simply gets throttled, at hours the system
/// picks rather than the ones that matter. So the budget goes where it shows:
/// often while the day is moving, rarely at night, and rarely on the long
/// periods, whose daily buckets barely move from one hour to the next.
enum WidgetRefresh {
    /// Quiet hours, local time: nothing worth spending a reload on.
    private static let nightStart = 1
    private static let nightEnd = 6

    static func interval(period: WidgetPeriod, activeVisitors: Int? = nil,
                         now: Date = .now, calendar: Calendar = .current) -> TimeInterval {
        let hour = calendar.component(.hour, from: now)
        if hour >= nightStart, hour < nightEnd { return 3 * 3_600 }
        switch period {
        case .last7Days, .last30Days:
            return 3_600
        case .today, .last24Hours:
            return (activeVisitors ?? 0) > 0 ? 20 * 60 : 45 * 60
        }
    }

    static func policy(period: WidgetPeriod, activeVisitors: Int? = nil,
                       now: Date = .now, calendar: Calendar = .current) -> TimelineReloadPolicy {
        .after(now.addingTimeInterval(interval(period: period, activeVisitors: activeVisitors,
                                               now: now, calendar: calendar)))
    }

    /// Realtime widgets live on a shorter leash: their whole point is the
    /// number of people on the site right now.
    static func livePolicy(activeVisitors: Int?, now: Date = .now, calendar: Calendar = .current) -> TimelineReloadPolicy {
        let hour = calendar.component(.hour, from: now)
        if hour >= nightStart, hour < nightEnd { return .after(now.addingTimeInterval(2 * 3_600)) }
        return .after(now.addingTimeInterval((activeVisitors ?? 0) > 0 ? 15 * 60 : 40 * 60))
    }

    /// Smart Stack: a site that is moving, or that has people on it, deserves
    /// to come up before one that has been flat all day. The score is relative
    /// to this widget's other entries, so the scale only has to be consistent.
    static func relevance(change: Double?, activeVisitors: Int? = nil,
                          duration: TimeInterval = 3_600) -> TimelineEntryRelevance {
        var score = 10.0
        if let change, change.isFinite {
            score += min(abs(change) * 200, 60)
        }
        if let activeVisitors, activeVisitors > 0 {
            score += min(Double(activeVisitors) / 25 * 30, 30)
        }
        return TimelineEntryRelevance(score: Float(score), duration: duration)
    }
}
