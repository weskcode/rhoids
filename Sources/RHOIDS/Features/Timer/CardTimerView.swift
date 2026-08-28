import SwiftUI

/// Numeric countdown displayed inside a rounded material card
/// with a linear progress bar beneath.
struct CardTimerView: View {
    let endDate: Date
    let progress: Double
    var showsCountdown = true
    var isStopping = false
    var frozenRemaining: TimeInterval?

    @ScaledMetric private var countdownSize: CGFloat
    @ScaledMetric(relativeTo: .largeTitle) private var cardHeight: CGFloat = 132
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Defaults match the full-screen live timer; previews can pass a smaller
    /// `countdownSize` so the digits sit comfortably inside a reduced card.
    init(
        endDate: Date,
        progress: Double,
        showsCountdown: Bool = true,
        isStopping: Bool = false,
        frozenRemaining: TimeInterval? = nil,
        countdownSize: CGFloat = 72
    ) {
        self.endDate = endDate
        self.progress = progress
        self.showsCountdown = showsCountdown
        self.isStopping = isStopping
        self.frozenRemaining = frozenRemaining
        self._countdownSize = ScaledMetric(wrappedValue: countdownSize, relativeTo: .largeTitle)
    }

    var body: some View {
        VStack(spacing: 18) {
            timerCard

            progressRail
        }
        .scaleEffect(isStopping && !reduceMotion ? 0.98 : 1)
        .opacity(isStopping ? 0.76 : 1)
        .animation(AppMotion.reveal(reduceMotion: reduceMotion), value: showsCountdown)
        .animation(AppMotion.feedback(reduceMotion: reduceMotion), value: isStopping)
    }

    private var timerCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .shadow(
                    color: .black.opacity(showsCountdown && !reduceMotion ? 0.08 : 0.05),
                    radius: showsCountdown ? 22 : 16,
                    y: showsCountdown ? 12 : 8
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(showsCountdown ? 0.04 : 0.06), lineWidth: 1)
                }

            idleFace
                .opacity(showsCountdown ? 0 : 1)
                .scaleEffect(showsCountdown && !reduceMotion ? 0.98 : 1)

            if showsCountdown {
                TimerCountdownText(endDate: endDate, size: countdownSize, frozenRemaining: frozenRemaining)
                    .transition(.scale(scale: 0.98))
            }
        }
        .padding(.horizontal, showsCountdown ? 28 : 0)
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .accessibilityHidden(!showsCountdown)
    }

    private var idleFace: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.accentColor.opacity(0.24))
                .frame(width: 76, height: 10)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(index == 1 ? 0.13 : 0.09))
                        .frame(width: index == 1 ? 34 : 24, height: 8)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var progressRail: some View {
        ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(.accentColor)
            .scaleEffect(x: 1, y: showsCountdown ? 1.15 : 0.85, anchor: .center)
            .opacity(showsCountdown ? 1 : 0.68)
            .animation(AppMotion.progress(reduceMotion: reduceMotion), value: progress)
    }
}

#if DEBUG
#Preview {
    CardTimerView(
        endDate: Date().addingTimeInterval(120),
        progress: 0.35
    )
    .padding(32)
}
#endif
