import SwiftUI

/// Full-width horizontal bar that drains as time elapses,
/// with the countdown displayed above.
struct ProgressTimerView: View {
    let endDate: Date
    let progress: Double
    var showsCountdown = true
    var frozenRemaining: TimeInterval?

    @ScaledMetric(relativeTo: .body) private var barHeight: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var remaining: Double { max(1 - progress, 0) }

    var body: some View {
        VStack(spacing: 32) {
            if showsCountdown {
                TimerCountdownText(endDate: endDate, size: 64, frozenRemaining: frozenRemaining)
            }

            GeometryReader { geo in
                let barWidth = geo.size.width

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: barHeight)

                    // Fill
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: barWidth * remaining, height: barHeight)
                        .animation(AppMotion.progress(reduceMotion: reduceMotion), value: remaining)
                }
            }
            .frame(height: barHeight)

        }
    }
}

#if DEBUG
#Preview("30%") {
    ProgressTimerView(
        endDate: Date().addingTimeInterval(120),
        progress: 0.3
    )
    .padding(32)
}

#Preview("80%") {
    ProgressTimerView(
        endDate: Date().addingTimeInterval(20),
        progress: 0.8
    )
    .padding(32)
}
#endif
