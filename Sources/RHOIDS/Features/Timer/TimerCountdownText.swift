import SwiftUI

struct TimerCountdownText: View {
    let endDate: Date
    let size: CGFloat
    var weight: Font.Weight = .thin
    var frozenRemaining: TimeInterval?

    private var safeEndDate: Date { max(endDate, Date()) }

    /// Remaining time for VoiceOver. Uses the frozen value at completion/stop,
    /// otherwise the live distance to the end date.
    private var accessibilityRemaining: TimeInterval {
        frozenRemaining ?? max(safeEndDate.timeIntervalSinceNow, 0)
    }

    var body: some View {
        Group {
            if let frozenRemaining {
                Text(Self.formatted(frozenRemaining))
            } else {
                Text(timerInterval: Date()...safeEndDate, countsDown: true)
            }
        }
            .font(.system(size: size, weight: weight, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .contentTransition(.numericText())
            .accessibilityLabel("Time remaining")
            .accessibilityValue(Self.formatted(accessibilityRemaining))
    }

    private static func formatted(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(ceil(duration)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
