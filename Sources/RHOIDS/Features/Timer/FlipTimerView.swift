import SwiftUI

/// Retro split-flap clock with individual digit tiles
/// and a subtle split line through each tile.
struct FlipTimerView: View {
    let endDate: Date
    let progress: Double
    var showsCountdown = true
    var frozenRemaining: TimeInterval?

    @ScaledMetric(relativeTo: .largeTitle) private var tileWidth: CGFloat = 52
    @ScaledMetric(relativeTo: .largeTitle) private var tileHeight: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reservesHourColumn: Bool
    @State private var previewTotalSeconds: Int

    init(endDate: Date, progress: Double, showsCountdown: Bool = true, frozenRemaining: TimeInterval? = nil) {
        self.endDate = endDate
        self.progress = progress
        self.showsCountdown = showsCountdown
        self.frozenRemaining = frozenRemaining

        let initialRemaining = max(Int(ceil(frozenRemaining ?? endDate.timeIntervalSinceNow)), 0)
        self._reservesHourColumn = State(initialValue: initialRemaining >= 3600)
        self._previewTotalSeconds = State(initialValue: initialRemaining)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(endDate.timeIntervalSince(context.date), 0)
            let liveTotalSeconds = Int(ceil(remaining))
            let frozenTotalSeconds = frozenRemaining.map { max(Int(ceil($0)), 0) }
            let totalSeconds = frozenTotalSeconds ?? (showsCountdown ? liveTotalSeconds : previewTotalSeconds)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60

            VStack(spacing: 20) {
                HStack(spacing: 4) {
                    if reservesHourColumn {
                        digitPair(hours)
                            .opacity(hours > 0 ? 1 : 0)
                            .accessibilityHidden(hours <= 0)
                        colonSeparator
                            .opacity(hours > 0 ? 1 : 0)
                            .accessibilityHidden(hours <= 0)
                    }

                    digitPair(minutes)
                    colonSeparator
                    digitPair(seconds)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    accessibilityText(hours: hours, minutes: minutes, seconds: seconds)
                )

            }
        }
        .onChange(of: endDate) { _, newEndDate in
            updatePreviewTotalSeconds(for: newEndDate)
        }
    }

    // MARK: - Subviews

    private func digitPair(_ value: Int) -> some View {
        HStack(spacing: 4) {
            FlipDigitTile(
                digit: value / 10,
                width: tileWidth,
                height: tileHeight,
                reduceMotion: reduceMotion
            )
            FlipDigitTile(
                digit: value % 10,
                width: tileWidth,
                height: tileHeight,
                reduceMotion: reduceMotion
            )
        }
    }

    private var colonSeparator: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color(.tertiaryLabel))
                .frame(width: 6, height: 6)
            Circle()
                .fill(Color(.tertiaryLabel))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Accessibility

    private func accessibilityText(hours: Int, minutes: Int, seconds: Int) -> String {
        if hours > 0 {
            return "Time remaining: \(hours) hours, \(minutes) minutes, \(seconds) seconds"
        }
        return "Time remaining: \(minutes) minutes, \(seconds) seconds"
    }

    private func updatePreviewTotalSeconds(for newEndDate: Date) {
        guard !showsCountdown else { return }

        let newTotalSeconds = max(Int(ceil(newEndDate.timeIntervalSinceNow)), 0)
        guard newTotalSeconds != previewTotalSeconds else { return }

        withAnimation(AppMotion.optionSelection(reduceMotion: reduceMotion)) {
            previewTotalSeconds = newTotalSeconds
            reservesHourColumn = newTotalSeconds >= 3600
        }
    }
}

private struct FlipDigitTile: View {
    let digit: Int
    let width: CGFloat
    let height: CGFloat
    let reduceMotion: Bool

    @State private var displayedDigit: Int
    @State private var isFlipping = false

    init(digit: Int, width: CGFloat, height: CGFloat, reduceMotion: Bool) {
        self.digit = digit
        self.width = width
        self.height = height
        self.reduceMotion = reduceMotion
        self._displayedDigit = State(initialValue: digit)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(
                    color: .black.opacity(isFlipping && !reduceMotion ? 0.08 : 0.03),
                    radius: isFlipping ? 10 : 4,
                    y: isFlipping ? 5 : 2
                )

            Rectangle()
                .fill(Color(.separator).opacity(0.28))
                .frame(height: 1)

            Text("\(displayedDigit)")
                .font(.system(size: height * 0.6, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .baselineOffset(isFlipping && !reduceMotion ? -1 : 0)
        }
        .frame(width: width, height: height)
        .clipShape(.rect(cornerRadius: 8, style: .continuous))
        .rotation3DEffect(
            .degrees(isFlipping && !reduceMotion ? -8 : 0),
            axis: (x: 1, y: 0, z: 0),
            anchor: .center,
            perspective: 0.7
        )
        .scaleEffect(isFlipping && !reduceMotion ? 0.995 : 1)
        .animation(AppMotion.digitFlip(reduceMotion: reduceMotion), value: isFlipping)
        .onChange(of: digit) { _, newDigit in
            updateDigit(newDigit)
        }
        .onChange(of: reduceMotion) { _, _ in
            displayedDigit = digit
            isFlipping = false
        }
    }

    private func updateDigit(_ newDigit: Int) {
        guard newDigit != displayedDigit else { return }

        if reduceMotion {
            displayedDigit = newDigit
            return
        }

        withAnimation(AppMotion.digitFlip(reduceMotion: reduceMotion)) {
            isFlipping = true
        } completion: {
            displayedDigit = newDigit
            withAnimation(AppMotion.digitFlip(reduceMotion: reduceMotion)) {
                isFlipping = false
            }
        }
    }
}

#if DEBUG
#Preview("3:00") {
    FlipTimerView(
        endDate: Date().addingTimeInterval(180),
        progress: 0.0
    )
    .padding(32)
}

#Preview("0:42") {
    FlipTimerView(
        endDate: Date().addingTimeInterval(42),
        progress: 0.72
    )
    .padding(32)
}
#endif
