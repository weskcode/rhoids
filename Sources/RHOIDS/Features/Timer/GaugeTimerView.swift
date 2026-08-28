import SwiftUI

/// Segmented horizontal gauge that drains segment by segment
/// as time elapses - like a battery or fuel indicator.
struct GaugeTimerView: View {
    let endDate: Date
    let progress: Double
    var showsCountdown = true
    var frozenRemaining: TimeInterval?

    @ScaledMetric(relativeTo: .body) private var segmentHeight: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let segmentCount = 12
    private var remaining: Double { max(1 - progress, 0) }
    private var filledCount: Int {
        Int(ceil(remaining * Double(Self.segmentCount)))
    }
    var body: some View {
        VStack(spacing: 24) {
            if showsCountdown {
                TimerCountdownText(endDate: endDate, size: 56, frozenRemaining: frozenRemaining)
            }

            segments
        }
    }

    // MARK: - Segments

    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(0..<Self.segmentCount, id: \.self) { index in
                let isFilled = index < filledCount
                RoundedRectangle(cornerRadius: 4)
                    .fill(isFilled ? Color.accentColor : Color(.tertiarySystemFill))
                    .frame(height: segmentHeight)
                    .scaleEffect(y: reduceMotion ? 1 : (isFilled ? 1 : 0.84), anchor: .bottom)
                    .opacity(isFilled ? 1 : 0.58)
                    .animation(
                        AppMotion.feedback(reduceMotion: reduceMotion),
                        value: filledCount
                    )
            }
        }
    }
}

#if DEBUG
#Preview("Full") {
    GaugeTimerView(
        endDate: Date().addingTimeInterval(180),
        progress: 0.0
    )
    .padding(32)
}

#Preview("Half") {
    GaugeTimerView(
        endDate: Date().addingTimeInterval(90),
        progress: 0.5
    )
    .padding(32)
}

#Preview("Nearly done") {
    GaugeTimerView(
        endDate: Date().addingTimeInterval(15),
        progress: 0.9
    )
    .padding(32)
}
#endif
