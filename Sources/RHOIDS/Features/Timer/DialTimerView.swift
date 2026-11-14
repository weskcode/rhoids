import SwiftUI

/// Kitchen-timer dial with tick marks and a sweeping
/// accent-colored arc that shrinks as time elapses.
struct DialTimerView: View {
    let endDate: Date
    let progress: Double
    var showsCountdown = true
    var frozenRemaining: TimeInterval?
    var maxSize: CGFloat?

    @ScaledMetric(relativeTo: .largeTitle) private var dialSize: CGFloat = 260
    @ScaledMetric(relativeTo: .largeTitle) private var arcWidth: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let tickCount = 60
    private static let majorInterval = 5

    private var effectiveDialSize: CGFloat {
        min(dialSize, maxSize ?? 320)
    }

    var body: some View {
        let scale = effectiveDialSize / 260
        let arcPadding = 20 * scale
        let countdownSize = 42 * scale

        ZStack {
            // Tick marks
            tickMarks

            // Remaining arc - trims from the leading edge so it drains clockwise
            Circle()
                .trim(from: progress, to: 1)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: arcWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(AppMotion.progress(reduceMotion: reduceMotion), value: progress)
                .padding(arcPadding)

            // Center countdown
            if showsCountdown {
                TimerCountdownText(endDate: endDate, size: countdownSize, weight: .light, frozenRemaining: frozenRemaining)
                    .padding(.horizontal, arcPadding + arcWidth + 12)
            }
        }
        .frame(width: effectiveDialSize, height: effectiveDialSize)
    }

    // MARK: - Tick Marks

    private var tickMarks: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRadius = min(size.width, size.height) / 2

            for tick in 0..<Self.tickCount {
                let isMajor = tick % Self.majorInterval == 0
                let angle = Angle.degrees(Double(tick) / Double(Self.tickCount) * 360 - 90)
                let length: CGFloat = isMajor ? 12 : 6
                let innerRadius = outerRadius - length

                let outer = CGPoint(
                    x: center.x + cos(angle.radians) * outerRadius,
                    y: center.y + sin(angle.radians) * outerRadius
                )
                let inner = CGPoint(
                    x: center.x + cos(angle.radians) * innerRadius,
                    y: center.y + sin(angle.radians) * innerRadius
                )

                var path = Path()
                path.move(to: outer)
                path.addLine(to: inner)

                context.stroke(
                    path,
                    with: .color(Color(.tertiaryLabel)),
                    lineWidth: isMajor ? 2 : 1
                )
            }
        }
    }
}

#if DEBUG
#Preview("25%") {
    DialTimerView(
        endDate: Date().addingTimeInterval(135),
        progress: 0.25
    )
    .padding()
}

#Preview("75%") {
    DialTimerView(
        endDate: Date().addingTimeInterval(45),
        progress: 0.75
    )
    .padding()
}
#endif
