import Foundation

/// The visitors online, as the widgets have observed them.
///
/// Umami answers "how many right now" but serves no minute-by-minute series,
/// so the Live widget keeps its own short history in the App Group: every
/// refresh appends the count it just read, and the sparkline shows the last
/// hours. It costs no request, and it is honest about being sampled — the
/// points are spaced by whatever the reload budget allowed.
enum LiveHistoryStore {
    private static let key = "widget.live.history"
    private static let maxSamples = 24
    private static let maxAge: TimeInterval = 24 * 3_600

    private static var stored: [String: [[Double]]] {
        get { AppGroup.defaults.dictionary(forKey: key) as? [String: [[Double]]] ?? [:] }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }

    static func history(for websiteID: String, now: Date = .now) -> [TimeSeriesPoint] {
        points(stored[websiteID] ?? [], now: now)
    }

    /// Appends one observation and returns the trimmed history, newest last.
    @discardableResult
    static func record(_ count: Int, for websiteID: String, at date: Date = .now) -> [TimeSeriesPoint] {
        var all = stored
        var samples = all[websiteID] ?? []
        samples.append([date.timeIntervalSince1970, Double(count)])
        samples = Array(samples.suffix(maxSamples))
        all[websiteID] = samples
        // Websites removed from every widget would keep their history for ever.
        all = all.filter { _, value in
            guard let last = value.last?.first else { return false }
            return date.timeIntervalSince1970 - last < maxAge
        }
        stored = all
        return points(samples, now: date)
    }

    private static func points(_ samples: [[Double]], now: Date) -> [TimeSeriesPoint] {
        samples.compactMap { sample in
            guard sample.count == 2, now.timeIntervalSince1970 - sample[0] < maxAge else { return nil }
            return TimeSeriesPoint(date: Date(timeIntervalSince1970: sample[0]), value: sample[1])
        }
    }
}
