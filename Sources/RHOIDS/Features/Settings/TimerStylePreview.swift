import SwiftUI

struct TimerStylePreview: View {
    let style: TimerStyle

    private let remaining: TimeInterval = 157
    private let progress = 0.28

    var body: some View {
        visual
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var visual: some View {
        switch style {
        case .card:
            CardTimerView(
                endDate: Date().addingTimeInterval(remaining),
                progress: progress,
                frozenRemaining: remaining
            )
            .scaleEffect(0.72)
        case .ring:
            RingTimerView(
                endDate: Date().addingTimeInterval(remaining),
                progress: progress,
                diameter: 124,
                strokeWidth: 8,
                countdownSize: 23,
                frozenRemaining: remaining
            )
        case .progress:
            ProgressTimerView(
                endDate: Date().addingTimeInterval(remaining),
                progress: progress,
                frozenRemaining: remaining
            )
            .frame(maxWidth: 260)
            .scaleEffect(0.78)
        case .flip:
            FlipTimerView(
                endDate: Date().addingTimeInterval(remaining),
                progress: progress,
                frozenRemaining: remaining
            )
            .scaleEffect(0.72)
        case .dial:
            DialTimerView(
                endDate: Date().addingTimeInterval(remaining),
                progress: progress,
                frozenRemaining: remaining
            )
            .scaleEffect(0.48)
        case .gauge:
            GaugeTimerView(
                endDate: Date().addingTimeInterval(remaining),
                progress: progress,
                frozenRemaining: remaining
            )
            .frame(maxWidth: 260)
            .scaleEffect(0.78)
        }
    }
}

#if DEBUG
    #Preview {
        VStack {
            TimerStylePreview(style: .card)
            TimerStylePreview(style: .ring)
            TimerStylePreview(style: .flip)
        }
    }
#endif
