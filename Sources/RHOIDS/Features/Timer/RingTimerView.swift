import SwiftUI

/// Circular progress ring with the countdown centered inside.
struct RingTimerView: View {
    let endDate: Date
    let progress: Double
    var showsCountdown = true
    var diameter: CGFloat?
    var strokeWidth: CGFloat?
    /// Point size of the centered countdown. Defaults to the live timer screen's
    /// size; the settings preview passes a smaller value to match its shrunk ring.
    var countdownSize: CGFloat = 48
    var frozenRemaining: TimeInterval?

    @ScaledMetric(relativeTo: .largeTitle) private var defaultRingSize: CGFloat = 260
    @ScaledMetric(relativeTo: .largeTitle) private var defaultLineWidth: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var effectiveRingSize: CGFloat { diameter ?? defaultRingSize }
    private var effectiveLineWidth: CGFloat { strokeWidth ?? defaultLineWidth }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: effectiveLineWidth)

            // Fill - trims from the leading edge so the ring drains clockwise
            Circle()
                .trim(from: progress, to: 1)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: effectiveLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(AppMotion.progress(reduceMotion: reduceMotion), value: progress)

            // Countdown
            if showsCountdown {
                TimerCountdownText(endDate: endDate, size: countdownSize, weight: .light, frozenRemaining: frozenRemaining)
            }
        }
        .frame(width: effectiveRingSize, height: effectiveRingSize)
    }
}

#if DEBUG
#Preview("25%") {
    RingTimerView(
        endDate: Date().addingTimeInterval(120),
        progress: 0.25
    )
    .padding()
}

#Preview("75%") {
    RingTimerView(
        endDate: Date().addingTimeInterval(30),
        progress: 0.75
    )
    .padding()
}
#endif
