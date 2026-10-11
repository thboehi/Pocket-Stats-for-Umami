import SwiftUI
import WidgetKit

@main
struct AnalyticsWidgetBundle: WidgetBundle {
    var body: some Widget {
        WebsiteWidget()
        WatchlistWidget()
        BreakdownWidget()
        LiveWidget()
        TotalWidget()
        LiveVisitorsControl()
    }
}
