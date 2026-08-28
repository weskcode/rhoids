import SwiftUI

/// Custom duration picker using the Digital Crown.
///
/// HIG compliance:
/// - W-DC-02: Crown bound to precise 1-minute increments with haptic detents
/// - W-DC-04: Visual feedback synced frame-by-frame with Crown rotation
/// - W-DC-05: Updates on each Crown increment immediately
/// - W-AC-03: Provides accessibilityAdjustableAction for VoiceOver
struct WatchCustomDurationView: View {
    let appState: WatchAppState
    @Binding var timerVM: WatchTimerViewModel?

    @State private var minutes: Double = 3.0
    @AppStorage("lastCustomDuration") private var savedDuration: Double = 180
    @FocusState private var isCrownFocused: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            Text("Set Duration")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(Int(minutes))")
                .font(.system(size: 52, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: Int(minutes))

            Text(Int(minutes) == 1 ? "minute" : "minutes")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button(action: { startCustomTimer() }) {
                Label("Start", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brand)
            .accessibilityLabel("Start \(Int(minutes)) minute timer")
            .accessibilityHint("Double-tap to begin countdown")
        }
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $minutes,
            from: 1.0,
            through: 30.0,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Custom duration picker")
        .accessibilityValue("\(Int(minutes)) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                minutes = min(minutes + 1, 30)
            case .decrement:
                minutes = max(minutes - 1, 1)
            @unknown default:
                break
            }
        }
        .onAppear {
            // Restore last used custom duration
            let stored = savedDuration / 60
            if (1...30).contains(stored) {
                minutes = stored.rounded()
            }
            // Auto-focus for Digital Crown binding (W-DC-02)
            isCrownFocused = true
        }
    }

    private func startCustomTimer() {
        let duration = TimeInterval(Int(minutes)) * 60
        savedDuration = duration

        let endDate = Date().addingTimeInterval(duration)
        let preset = PresetTimer.custom

        let vm = WatchTimerViewModel(timerService: appState.timerService)
        // Set initial state synchronously to avoid race with the event stream.
        vm.endDate = endDate
        vm.plannedDuration = duration
        vm.presetName = preset.name
        vm.presetIcon = preset.systemImage
        timerVM = vm

        Task {
            await appState.timerService.start(duration: duration, preset: preset)
        }

        // Pop back to home then show the timer after navigation settles
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            appState.showTimer = true
        }
    }
}
