import SwiftUI

/// Miniature of the app icon, kept in lockstep with
/// `Sources/RHOIDS/IconLayers/foreground.svg`: navy gradient tile, green 270°
/// arc with the elapsed first quarter (12 → 3 o'clock) open, four faint ticks
/// in that open quarter, and a toilet roll seen end-on with a see-through
/// center. Proportions come from the SVG's 1024-point canvas.
struct WidgetAppIcon: View {
    var size: CGFloat = 44
    var isAccented = false

    private static let kraft = Color(red: 201 / 255, green: 165 / 255, blue: 122 / 255)
    // Matches the icon art (#34D46E), not `Color.brand`, so the widget mirrors the icon exactly.
    private static let arcGreen = Color(red: 52 / 255, green: 212 / 255, blue: 110 / 255)

    private var cornerRadius: CGFloat { size * 0.223 }
    private var strokeWidth: CGFloat { max(canvas(44), 2) }
    private var tickWidth: CGFloat { max(canvas(10), 1) }

    /// Converts a length on the 1024-point icon canvas to this view's size.
    private func canvas(_ points: CGFloat) -> CGFloat {
        size * points / 1024
    }

    private var background: AnyShapeStyle {
        if isAccented {
            AnyShapeStyle(Color.primary.opacity(0.12))
        } else {
            AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 27 / 255, green: 58 / 255, blue: 92 / 255),
                    Color(red: 13 / 255, green: 31 / 255, blue: 51 / 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(background)

            // Timer arc with the first quarter elapsed: SwiftUI's Circle path
            // starts at 3 o'clock and winds clockwise, so an unrotated trim to
            // 0.75 sweeps 3 → 6 → 9 → 12 and leaves the top-right quadrant open.
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(isAccented ? Color.primary : Self.arcGreen,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: canvas(704), height: canvas(704))

            ElapsedQuarterTicks(innerRadius: canvas(334), outerRadius: canvas(370))
                .stroke(isAccented ? Color.primary.opacity(0.5) : Color.white.opacity(0.5),
                        style: StrokeStyle(lineWidth: tickWidth, lineCap: .round))

            Annulus(outerRadius: canvas(270), innerRadius: canvas(124))
                .fill(isAccented ? Color.primary : Color.white, style: FillStyle(eoFill: true))

            Annulus(outerRadius: canvas(124), innerRadius: canvas(96))
                .fill(isAccented ? Color.primary.opacity(0.5) : Self.kraft, style: FillStyle(eoFill: true))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A ring between two radii, centered in its frame. Fill it with `eoFill` so
/// the center stays see-through.
private struct Annulus: Shape {
    var outerRadius: CGFloat
    var innerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for radius in [outerRadius, innerRadius] {
            path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius,
                                       width: radius * 2, height: radius * 2))
        }
        return path
    }
}

/// Four radial ticks in the open top-right quarter, at -72°, -54°, -36° and
/// -18° (0° = 3 o'clock, negative = counter-clockwise on screen).
private struct ElapsedQuarterTicks: Shape {
    var innerRadius: CGFloat
    var outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for degrees in [-72.0, -54.0, -36.0, -18.0] {
            let angle = degrees * .pi / 180
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            path.move(to: CGPoint(x: rect.midX + direction.x * innerRadius,
                                  y: rect.midY + direction.y * innerRadius))
            path.addLine(to: CGPoint(x: rect.midX + direction.x * outerRadius,
                                     y: rect.midY + direction.y * outerRadius))
        }
        return path
    }
}

@available(*, deprecated, renamed: "WidgetAppIcon")
typealias WidgetIconArc = WidgetAppIcon
