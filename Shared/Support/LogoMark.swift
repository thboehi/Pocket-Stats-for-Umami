import SwiftUI

/// The app logo: three ascending bars above a half disc. Same geometry as the
/// app icon (see README › App icon): the bar group is as wide as the disc's
/// diameter and as tall as its radius, separated by 10% of the diameter.
struct LogoMark: Shape {
    func path(in rect: CGRect) -> Path {
        // Fit a (D wide) × (D/2 + 0.1·D + D/2 tall) drawing into rect.
        let diameter = min(rect.width, rect.height / 1.1)
        let radius = diameter / 2
        let gap = diameter * 0.1
        let origin = CGPoint(x: rect.midX - radius, y: rect.midY - (diameter + gap) / 2)
        let barsBottom = origin.y + radius

        var path = Path()
        let barWidth = diameter / 3.6
        let barGap = (diameter - 3 * barWidth) / 2
        // One corner radius for the bars and the half disc's two corners.
        let corner = barWidth * 0.15
        for (index, height) in [0.42, 0.71, 1.0].enumerated() {
            let barHeight = radius * height
            let bar = CGRect(x: origin.x + CGFloat(index) * (barWidth + barGap), y: barsBottom - barHeight, width: barWidth, height: barHeight)
            path.addRoundedRect(in: bar, cornerSize: CGSize(width: corner, height: corner), style: .circular)
        }

        // Half disc, flat side up, with its two corners filleted: each fillet
        // circle touches the flat edge and the inside of the big circle.
        let discTop = barsBottom + gap
        let center = CGPoint(x: rect.midX, y: discTop)
        let offset = sqrt((radius - corner) * (radius - corner) - corner * corner)
        let tangentAngle = Angle(radians: atan2(corner, offset))
        path.move(to: CGPoint(x: center.x - offset, y: discTop))
        path.addLine(to: CGPoint(x: center.x + offset, y: discTop))
        path.addArc(center: CGPoint(x: center.x + offset, y: discTop + corner), radius: corner,
                    startAngle: .degrees(-90), endAngle: tangentAngle, clockwise: false)
        path.addArc(center: center, radius: radius,
                    startAngle: tangentAngle, endAngle: .degrees(180) - tangentAngle, clockwise: false)
        path.addArc(center: CGPoint(x: center.x - offset, y: discTop + corner), radius: corner,
                    startAngle: .degrees(180) - tangentAngle, endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

#Preview {
    LogoMark()
        .frame(width: 200, height: 200)
        .padding()
}
