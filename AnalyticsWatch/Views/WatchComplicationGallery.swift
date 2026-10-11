#if DEBUG
import SwiftUI
import WidgetKit

/// Every complication at roughly its real size, with sample data.
/// `UMAMI_DEBUG_SCREEN=complications`, the counterpart of the iPhone's widget
/// gallery: a watch face cannot be composed from the command line, so this is
/// how their design is checked. Debug builds only.
///
/// Complications are drawn in `.vibrant` on a face, which flattens every colour
/// to one tint — exactly where a design that relies on colour alone breaks.
struct WatchComplicationGallery: View {
    private let snapshot = WebsiteSnapshot.sample()
    private let live = LiveSnapshot.sample()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                tile(width: 160, height: 72) { RectangularWebsiteWidgetView(snapshot: snapshot) }
                tile(width: 160, height: 72) { RectangularLiveWidgetView(snapshot: live) }
                HStack(spacing: 14) {
                    tile(width: 52, height: 52, shape: AnyShape(Circle())) { CircularWebsiteWidgetView(snapshot: snapshot) }
                    tile(width: 72, height: 72, shape: AnyShape(Circle())) { CornerWebsiteWidgetView(snapshot: snapshot) }
                }
                InlineWebsiteWidgetView(snapshot: snapshot)
                    .font(.caption2)
            }
            .environment(\.widgetRenderingMode, .vibrant)
            .foregroundStyle(.white)
            .padding(.vertical, 8)
        }
        .defaultScrollAnchor(WatchDebugLaunch.scrollAnchor)
    }

    private func tile(width: CGFloat, height: CGFloat, shape: AnyShape = AnyShape(.rect(cornerRadius: 12)),
                      @ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(width: width, height: height)
            .padding(4)
            .background(.white.opacity(0.14), in: shape)
    }
}
#endif
