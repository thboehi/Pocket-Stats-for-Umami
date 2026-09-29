#if DEBUG
import SwiftUI
import WidgetKit

/// Every widget at its real size on a 6.9" iPhone, with sample data.
/// `UMAMI_DEBUG_SCREEN=widgets`, used to check their design. Debug builds only.
struct WidgetGalleryView: View {
    private let snapshot = WebsiteSnapshot.sample()
    private let down = WebsiteSnapshot.samples[1]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 22) {
                    tile(width: 170, height: 170) { SmallWebsiteWidgetView(snapshot: snapshot, widgetKey: "x") }
                    tile(width: 170, height: 170) { SmallWebsiteWidgetView(snapshot: down, widgetKey: "x") }
                }
                tile(width: 364, height: 170) { MediumWebsiteWidgetView(snapshot: snapshot, widgetKey: "x") }
                tile(width: 364, height: 170) {
                    WatchlistWidgetView(snapshots: WebsiteSnapshot.samples, period: .today, maxRows: 3, widgetKey: "x")
                }
                tile(width: 364, height: 382) { LargeWebsiteWidgetView(snapshot: snapshot, widgetKey: "x") }
                tile(width: 364, height: 382) {
                    WatchlistWidgetView(snapshots: WebsiteSnapshot.samples, period: .today, maxRows: 7, widgetKey: "x")
                }
                HStack(spacing: 16) {
                    RectangularWebsiteWidgetView(snapshot: snapshot)
                        .frame(width: 172, height: 76)
                        .padding(8)
                        .background(.black.opacity(0.35), in: .rect(cornerRadius: 16))
                    CircularWebsiteWidgetView(snapshot: snapshot)
                        .frame(width: 76, height: 76)
                        .background(.black.opacity(0.35), in: .circle)
                }
                .foregroundStyle(.white)
                .environment(\.colorScheme, .dark)
                InlineWebsiteWidgetView(snapshot: snapshot)
                VisitorsSnippetView(snapshot: snapshot)
                    .frame(width: 364)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 24))
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(DebugLaunch.environment["UMAMI_DEBUG_GALLERY"] == "bottom" ? .bottom : .top)
        .background(Color(.systemGroupedBackground).opacity(0.5))
        .background(LinearGradient(colors: [.indigo.opacity(0.5), .teal.opacity(0.4)], startPoint: .top, endPoint: .bottom))
    }

    private func tile(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(16)
            .frame(width: width, height: height)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 24, style: .continuous))
    }
}
#endif

#if DEBUG
/// The widgets as they look on a Home Screen, for the App Store and website
/// screenshots (`UMAMI_DEBUG_SCREEN=home`). Debug builds only.
struct HomeScreenMockView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let samples = WebsiteSnapshot.samples
        VStack(spacing: 26) {
            HStack(spacing: 26) {
                widget(width: 170, height: 170) { SmallWebsiteWidgetView(snapshot: samples[0], widgetKey: "home") }
                widget(width: 170, height: 170) { SmallWebsiteWidgetView(snapshot: samples[1], widgetKey: "home") }
            }
            widget(width: 366, height: 170) {
                WatchlistWidgetView(snapshots: Array(samples[2...]), period: .today, maxRows: 3, widgetKey: "home")
            }
            widget(width: 366, height: 384) { LargeWebsiteWidgetView(snapshot: samples[0], widgetKey: "home") }
        }
        .padding(.top, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                LinearGradient(colors: colorScheme == .dark
                               ? [Color(red: 0.10, green: 0.08, blue: 0.30), Color(red: 0.02, green: 0.02, blue: 0.08)]
                               : [Color(red: 0.55, green: 0.52, blue: 1.0), Color(red: 0.27, green: 0.22, blue: 0.75)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(red: 0.45, green: 0.85, blue: 0.95).opacity(colorScheme == .dark ? 0.25 : 0.45), .clear],
                               center: .init(x: 0.85, y: 0.9), startRadius: 0, endRadius: 520)
            }
            .ignoresSafeArea()
        }
    }

    private func widget(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(16)
            .frame(width: width, height: height)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
#endif
