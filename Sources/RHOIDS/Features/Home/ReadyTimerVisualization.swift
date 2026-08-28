import SwiftUI

struct ReadyTimerVisualization: View {
    let preset: PresetTimer
    let duration: TimeInterval
    let timerStyle: TimerStyle
    let isPromoted: Bool
    let activationNamespace: Namespace.ID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            visual
                .frame(width: visualDimension, height: visualDimension)
                .scaleEffect(!reduceMotion && isPromoted ? promotedScale : 1)
                .timerActivationGeometry(activationNamespace)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.name) timer preview, \(DurationFormatter.formatted(duration))")
        .animation(AppMotion.contextChange(reduceMotion: reduceMotion), value: isPromoted)
        .animation(AppMotion.feedback(reduceMotion: reduceMotion), value: timerStyle)
    }

    @ViewBuilder
    private var visual: some View {
        let previewEndDate = Date().addingTimeInterval(max(duration, 1))

        switch timerStyle {
        case .card:
            // Show the selected duration as a static countdown so the card reads
            // as a real timer (matching the picker preview) instead of an
            // abstract placeholder. `frozenRemaining` keeps it from live-ticking.
            CardTimerView(
                endDate: previewEndDate,
                progress: 0,
                showsCountdown: true,
                frozenRemaining: duration,
                countdownSize: 52
            )
        case .ring:
            RingTimerView(
                endDate: previewEndDate,
                progress: 0,
                showsCountdown: false,
                diameter: isPromoted ? 248 : 176,
                strokeWidth: isPromoted ? 12 : 10
            )
        case .progress:
            ProgressTimerView(endDate: previewEndDate, progress: 0, showsCountdown: false)
        case .flip:
            FlipTimerView(endDate: previewEndDate, progress: 0, showsCountdown: false)
        case .dial:
            DialTimerView(endDate: previewEndDate, progress: 0, showsCountdown: false)
        case .gauge:
            GaugeTimerView(endDate: previewEndDate, progress: 0, showsCountdown: false)
        }
    }

    private var visualDimension: CGFloat {
        switch timerStyle {
        case .ring:
            isPromoted ? 260 : 184
        default:
            isPromoted ? 260 : 220
        }
    }

    private var promotedScale: CGFloat {
        timerStyle == .ring ? 1 : 1.04
    }
}

extension View {
    @ViewBuilder
    func timerActivationGeometry(_ namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedGeometryEffect(id: "timer-activation-visual", in: namespace)
        } else {
            self
        }
    }
}

#if DEBUG
#Preview("Ready") {
    ReadyTimerVisualization(
        preset: .recommended,
        duration: PresetTimer.recommended.duration,
        timerStyle: .ring,
        isPromoted: false,
        activationNamespace: nil
    )
    .padding()
}

#Preview("Starting") {
    ReadyTimerVisualization(
        preset: .recommended,
        duration: PresetTimer.recommended.duration,
        timerStyle: .ring,
        isPromoted: true,
        activationNamespace: nil
    )
    .padding()
}
#endif
