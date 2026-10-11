import SwiftUI

/// The UIKit system colours are declared `API_UNAVAILABLE(watchos)`, and on iOS
/// SwiftUI's own greens and reds resolve to exactly those values. One name per
/// intent, so no view has to know which platform it is drawing on.
extension Color {
    /// A figure that moved the right way, or someone being on the site now.
    static var positive: Color {
        #if os(watchOS)
        .green
        #else
        Color(.systemGreen)
        #endif
    }

    /// A figure that moved the wrong way.
    static var negative: Color {
        #if os(watchOS)
        .red
        #else
        Color(.systemRed)
        #endif
    }

    /// No movement worth a colour.
    static var muted: Color {
        #if os(watchOS)
        .gray
        #else
        Color(.systemGray)
        #endif
    }
}
