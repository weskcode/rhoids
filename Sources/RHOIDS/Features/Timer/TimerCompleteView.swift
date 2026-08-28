import SwiftUI

struct TimerCompleteView: View {
    let outcome: TimerOutcome
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentAppeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            completionIcon
                .opacity(contentAppeared ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (contentAppeared ? 1 : 0.92))

            VStack(spacing: 12) {
                Text(outcome.title)
                    .font(.largeTitle.bold())
                    .tracking(2)
                    .accessibilityAddTraits(.isHeader)

                Text(outcome.quip.body)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (contentAppeared ? 0 : 10))

            Spacer(minLength: 0)

            Button(action: { dismiss() }) {
                Label("Dismiss", systemImage: "stop.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .accessibilityHint("Closes the timer.")
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (contentAppeared ? 0 : 12))
        }
        .scenePadding(.horizontal)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        .task {
            withAnimation(AppMotion.timerCompletion(reduceMotion: reduceMotion)) {
                contentAppeared = true
            }
        }
    }

    @ViewBuilder
    private var completionIcon: some View {
        let icon = Image(systemName: outcome.iconSymbol)
            .font(.system(size: 80))
            .foregroundStyle(Color.accentColor)
            .symbolRenderingMode(.hierarchical)
            .accessibilityHidden(true)

        ZStack {
            // Soft brand glow behind the icon to make the payoff moment feel
            // rewarding. A radial gradient (no blur) keeps it GPU-cheap.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.22), Color.accentColor.opacity(0)],
                        center: .center,
                        startRadius: 6,
                        endRadius: 96
                    )
                )
                .frame(width: 184, height: 184)
                .accessibilityHidden(true)

            if reduceMotion {
                icon
            } else {
                icon.symbolEffect(.bounce, value: outcome.id)
            }
        }
    }
}

#Preview("Completed") {
    TimerCompleteView(outcome: .completed(TimerQuip.completionQuips[0]))
}

#Preview("Stopped early") {
    TimerCompleteView(outcome: .stoppedEarly(TimerQuip.earlyStopQuips[0]))
}
