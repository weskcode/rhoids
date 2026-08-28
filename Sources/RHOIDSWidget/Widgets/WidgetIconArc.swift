import SwiftUI

/// Miniature of the app icon, kept in lockstep with
/// `Sources/RHOIDS/IconLayers/foreground.svg`: navy gradient tile, 10% white
/// ring track, green 270° arc with the elapsed first quarter (12 → 3 o'clock)
/// open, and a bold white R centered in the ring.
struct WidgetAppIcon: View {
    var size: CGFloat = 44
    var isAccented = false

    private var strokeWidth: CGFloat { max(size * 0.043, 2) }
    private var fontSize: CGFloat { size * 0.31 }
    private var cornerRadius: CGFloat { size * 0.223 }
    private var ringPadding: CGFloat { size * 0.207 }

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

    private var arcStyle: AnyShapeStyle {
        if isAccented {
            AnyShapeStyle(Color.primary)
        } else {
            AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 74 / 255, green: 222 / 255, blue: 128 / 255),
                    Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
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

            if !isAccented {
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: strokeWidth)
                    .padding(ringPadding)
            }

            // Timer arc with the first quarter elapsed: SwiftUI's Circle path
            // starts at 3 o'clock and winds clockwise, so an unrotated trim to
            // 0.75 sweeps 3 → 6 → 9 → 12 and leaves the top-right quadrant open.
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(arcStyle, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .padding(ringPadding)

            Text("R")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(isAccented ? Color.primary : .white)
        }
        .frame(width: size, height: size)
    }
}

@available(*, deprecated, renamed: "WidgetAppIcon")
typealias WidgetIconArc = WidgetAppIcon
