#if DEBUG
import SwiftUI
import WidgetKit

/// Every widget at its real size on a 6.9" iPhone, with sample data.
/// `UMAMI_DEBUG_SCREEN=widgets`, used to check their design. Debug builds only.
///
/// The picker switches the rendering mode: the Home Screen tints and flattens
/// every colour (`.accented`), which is where badges and fills break.
struct WidgetGalleryView: View {
    @State private var mode: GalleryRenderingMode = .initial
    private let snapshot = WebsiteSnapshot.sample()
    private let down = WebsiteSnapshot.samples[1]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Picker("Rendering mode", selection: $mode) {
                    ForEach(GalleryRenderingMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                HStack(spacing: 22) {
                    tile(width: 170, height: 170) { SmallWebsiteWidgetView(snapshot: snapshot, widgetKey: "x") }
                    tile(width: 170, height: 170) { SmallWebsiteWidgetView(snapshot: down, widgetKey: "x") }
                }
                HStack(spacing: 22) {
                    tile(width: 170, height: 170) {
                        SmallWebsiteWidgetView(snapshot: snapshot.previewed(as: .bounceRate), widgetKey: "x")
                    }
                    tile(width: 170, height: 170) {
                        WatchlistWidgetView(snapshots: WebsiteSnapshot.samples, period: .today, maxRows: 2,
                                            widgetKey: "x", family: .systemSmall)
                    }
                }
                tile(width: 364, height: 170) { MediumWebsiteWidgetView(snapshot: snapshot, widgetKey: "x") }
                tile(width: 364, height: 170) {
                    MediumWebsiteWidgetView(snapshot: snapshot.previewed(as: .visitDuration), widgetKey: "x")
                }
                tile(width: 364, height: 170) {
                    WatchlistWidgetView(snapshots: WebsiteSnapshot.samples, period: .today, maxRows: 3, widgetKey: "x")
                }
                tile(width: 364, height: 382) { LargeWebsiteWidgetView(snapshot: snapshot, widgetKey: "x") }
                tile(width: 364, height: 382) {
                    LargeWebsiteWidgetView(snapshot: .sample(metric: .pageviews, breakdownType: .referrer), widgetKey: "x")
                }
                tile(width: 364, height: 382) {
                    WatchlistWidgetView(snapshots: WebsiteSnapshot.samples, period: .today, maxRows: 7,
                                        widgetKey: "x", family: .systemLarge)
                }
                HStack(spacing: 22) {
                    tile(width: 170, height: 170) {
                        BreakdownWidgetView(snapshot: .sample(type: .country), rowCount: 3, compact: true, widgetKey: "x")
                    }
                    tile(width: 170, height: 170) { LiveWidgetView(snapshot: .sample()) }
                }
                tile(width: 364, height: 170) {
                    BreakdownWidgetView(snapshot: .sample(type: .referrer), rowCount: 4, widgetKey: "x")
                }
                tile(width: 364, height: 170) { LiveWidgetView(snapshot: .sample(), showsPages: true) }
                tile(width: 364, height: 382) {
                    BreakdownWidgetView(snapshot: .sample(type: .path), rowCount: 8, widgetKey: "x")
                }
                HStack(spacing: 22) {
                    tile(width: 170, height: 170) { TotalWidgetView(snapshot: .sample(), widgetKey: "x") }
                    tile(width: 170, height: 170) {
                        TotalWidgetView(snapshot: .sample(metric: .pageviews), widgetKey: "x")
                    }
                }
                tile(width: 364, height: 170) {
                    TotalWidgetView(snapshot: .sample(), showsChart: true, widgetKey: "x")
                }
                HStack(spacing: 16) {
                    RectangularLiveWidgetView(snapshot: .sample())
                        .frame(width: 172, height: 76)
                        .padding(8)
                        .background(.black.opacity(0.35), in: .rect(cornerRadius: 16))
                }
                .environment(\.widgetRenderingMode, .vibrant)
                .foregroundStyle(.white)
                .environment(\.colorScheme, .dark)
                HStack(spacing: 16) {
                    RectangularWebsiteWidgetView(snapshot: snapshot)
                        .frame(width: 172, height: 76)
                        .padding(8)
                        .background(.black.opacity(0.35), in: .rect(cornerRadius: 16))
                    CircularWebsiteWidgetView(snapshot: snapshot)
                        .frame(width: 76, height: 76)
                        .background(.black.opacity(0.35), in: .circle)
                }
                .environment(\.widgetRenderingMode, .vibrant)
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
        .defaultScrollAnchor(scrollAnchor)
        .background(Color(.systemGroupedBackground).opacity(0.5))
        .background(LinearGradient(colors: [.indigo.opacity(0.5), .teal.opacity(0.4)], startPoint: .top, endPoint: .bottom))
    }

    /// `UMAMI_DEBUG_GALLERY=bottom|center`, to screenshot the lower widgets.
    private var scrollAnchor: UnitPoint {
        switch DebugLaunch.environment["UMAMI_DEBUG_GALLERY"] {
        case "bottom": .bottom
        case "center": .center
        default: .top
        }
    }

    private func tile(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .environment(\.widgetRenderingMode, mode.widgetRenderingMode)
            // The system paints the accent groups itself; this only approximates
            // the flattening, enough to catch white-on-white and lost fills.
            .foregroundStyle(mode == .fullColor ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .environment(\.colorScheme, mode == .fullColor ? .light : .dark)
            .padding(16)
            .frame(width: width, height: height)
            .background {
                // Tinted widgets keep no background of their own: the wallpaper
                // shows through a faint scrim, as on a clear Home Screen.
                if mode == .fullColor {
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.systemBackground))
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.black.opacity(0.28))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                        }
                }
            }
    }
}

enum GalleryRenderingMode: CaseIterable {
    case fullColor, accented, vibrant

    /// `UMAMI_DEBUG_GALLERY_MODE=tinted|lockscreen`, to screenshot a mode
    /// without tapping the picker.
    static var initial: GalleryRenderingMode {
        switch DebugLaunch.environment["UMAMI_DEBUG_GALLERY_MODE"] {
        case "tinted", "accented": .accented
        case "lockscreen", "vibrant": .vibrant
        default: .fullColor
        }
    }

    var title: String {
        switch self {
        case .fullColor: "Full color"
        case .accented: "Tinted"
        case .vibrant: "Lock Screen"
        }
    }

    var widgetRenderingMode: WidgetRenderingMode {
        switch self {
        case .fullColor: .fullColor
        case .accented: .accented
        case .vibrant: .vibrant
        }
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
        // One of every widget, in the order they read best: the two newcomers
        // first, then the figures, the list and the ranking. The large one
        // runs off the bottom of the screen, as it would on a real page.
        // A page taller than the screen, so the last widget runs off the
        // bottom as it would on a real Home Screen. Scrolling is off: the
        // ScrollView is only here to anchor the overflow at the top.
        ScrollView {
            VStack(spacing: 26) {
                HStack(spacing: 26) {
                    widget(width: 170, height: 170) { LiveWidgetView(snapshot: .sample()) }
                    widget(width: 170, height: 170) { TotalWidgetView(snapshot: .sample(), widgetKey: "home") }
                }
                widget(width: 366, height: 170) {
                    WatchlistWidgetView(snapshots: Array(samples[2...]), period: .today, maxRows: 3, widgetKey: "home")
                }
                widget(width: 366, height: 170) {
                    BreakdownWidgetView(snapshot: .sample(type: .country), rowCount: 3, widgetKey: "home")
                }
                widget(width: 366, height: 384) { LargeWebsiteWidgetView(snapshot: samples[0], widgetKey: "home") }
            }
            .padding(.top, 30)
            .frame(maxWidth: .infinity)
        }
        .scrollDisabled(true)
        .scrollIndicators(.hidden)
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
