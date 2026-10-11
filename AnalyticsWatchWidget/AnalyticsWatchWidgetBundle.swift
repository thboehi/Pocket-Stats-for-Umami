import SwiftUI
import WidgetKit

/// The complications of the watch app. Two, because a watch face has room for
/// one glance at a time: the figure of a website, or who is on it right now.
@main
struct AnalyticsWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchWebsiteComplication()
        WatchLiveComplication()
    }
}
