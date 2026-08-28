import SwiftUI

/// The Watch app's main screen.
///
/// HIG compliance:
/// - W-GL-01: Hero START button visible without scrolling on all watch sizes
/// - W-NV-05: Primary action reachable within 1 tap from launch
/// - W-GL-02: Complete interaction in <5 seconds (tap START → done)
/// - W-DC-01: Digital Crown scrolls the preset list
/// - W-AC-01: All interactive elements have accessibility labels
struct WatchHomeView: View {
    @Bindable var appState: WatchAppState

    @State private var selectedPreset: PresetTimer = .recommended
    @State private var timerVM: WatchTimerViewModel?
    @State private var showCustomPicker = false

    @AppStorage("defaultPreset") private var defaultPresetID = ""
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    private var defaultPreset: PresetTimer {
        PresetTimer.all.first { $0.id.uuidString == defaultPresetID } ?? .recommended
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    heroStartButton

                    Divider()
                        .padding(.vertical, 4)

                    presetList

                    customNavigationLink
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("RHOIDS")
            .navigationDestination(isPresented: $appState.showTimer) {
                if let vm = timerVM {
                    WatchTimerView(viewModel: vm)
                }
            }
            .navigationDestination(isPresented: $showCustomPicker) {
                WatchCustomDurationView(appState: appState, timerVM: $timerVM)
            }
        }
        .onAppear {
            selectedPreset = defaultPreset
            setupConnectivityHandler()
            checkActiveTimer()
            // Ask the iPhone for its current timer state now that the
            // handler is wired up. The request made during session activation
            // can arrive before `onAppear` runs, in which case its response
            // was dropped - this retry keeps a phone-started timer from
            // being missed.
            appState.connectivityService.requestState()
#if DEBUG
            // Screenshot automation: start the selected preset on launch.
            // Enable with SIMCTL_CHILD_RHOIDS_DEMO_TIMER=1 xcrun simctl launch …
            if ProcessInfo.processInfo.environment["RHOIDS_DEMO_TIMER"] == "1" {
                startTimer()
            }
#endif
        }
    }

    // MARK: - Hero Start Button (W-GL-01, W-NV-05)

    private var heroStartButton: some View {
        Button(action: { startTimer() }) {
            VStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.title2)

                Text("START")
                    .font(.headline)

                if selectedPreset.duration > 0 {
                    Text("\(selectedPreset.name) \u{00B7} \(selectedPreset.formattedDuration)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .tint(.brand)
        .accessibilityLabel("Start \(selectedPreset.name) timer")
        .accessibilityHint("\(selectedPreset.formattedDuration) countdown. Double-tap to begin.")
    }

    // MARK: - Preset List

    private var presetList: some View {
        VStack(spacing: 6) {
            ForEach(PresetTimer.all.filter { !$0.isCustom }) { preset in
                WatchPresetRow(
                    preset: preset,
                    isSelected: selectedPreset == preset
                ) {
                    selectedPreset = preset
                    if hapticsEnabled {
                        WatchHaptics.presetSelected()
                    }
                }
            }
        }
    }

    // MARK: - Custom Duration Link

    private var customNavigationLink: some View {
        Button(action: { showCustomPicker = true }) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                Text("Custom")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set custom duration")
        .accessibilityHint("Opens duration picker with Digital Crown control")
    }

    // MARK: - Actions

    private func startTimer() {
        let duration = selectedPreset.duration
        guard duration > 0 else { return }

        let endDate = Date().addingTimeInterval(duration)

        let vm = WatchTimerViewModel(timerService: appState.timerService)
        // Set initial state synchronously to avoid race with the event stream.
        // The event stream will update these values when it receives .started,
        // but this ensures the view has valid data immediately.
        vm.endDate = endDate
        vm.plannedDuration = duration
        vm.presetName = selectedPreset.name
        vm.presetIcon = selectedPreset.systemImage

        timerVM = vm
        appState.showTimer = true

        Task {
            await appState.timerService.start(duration: duration, preset: selectedPreset)
        }
    }

    /// If the app launches while a timer is already running (e.g. started from iPhone),
    /// immediately show the timer view.
    private func checkActiveTimer() {
        Task {
            let isRunning = await appState.timerService.isRunning
            if isRunning {
                let vm = WatchTimerViewModel(timerService: appState.timerService)
                timerVM = vm
                appState.showTimer = true
            }
        }
    }

    private func setupConnectivityHandler() {
        appState.connectivityService.onPhoneTimerEvent = { [appState] message in
            switch message {
            case .timerStarted(let endDate, let presetName, let duration):
                let preset = PresetTimer.all.first { $0.name == presetName } ?? .recommended
                let vm = WatchTimerViewModel(timerService: appState.timerService)
                vm.endDate = endDate
                vm.plannedDuration = duration
                vm.presetName = presetName
                vm.presetIcon = preset.systemImage
                self.timerVM = vm
                appState.showTimer = true

                Task {
                    await appState.timerService.adopt(endDate: endDate, presetName: presetName, duration: duration)
                }

            case .timerCancelled:
                Task { await appState.timerService.cancelFromPhone() }

            case .timerCompleted(let presetName, let duration):
                Task {
                    await appState.timerService.completeFromPhone(
                        presetName: presetName,
                        duration: duration
                    )
                }

            case .stateResponse(let endDate, let isRunning, let presetName, let duration):
                if isRunning, let endDate, endDate > Date() {
                    let preset = PresetTimer.all.first { $0.name == (presetName ?? "") } ?? .recommended
                    let vm = WatchTimerViewModel(timerService: appState.timerService)
                    vm.endDate = endDate
                    vm.plannedDuration = duration
                    vm.presetName = presetName ?? preset.name
                    vm.presetIcon = preset.systemImage
                    vm.elapsed = max(duration - endDate.timeIntervalSinceNow, 0)
                    self.timerVM = vm
                    appState.showTimer = true

                    Task {
                        await appState.timerService.adopt(
                            endDate: endDate,
                            presetName: presetName ?? "Recommended",
                            duration: duration
                        )
                    }
                }

            default:
                break
            }
        }
    }
}

// MARK: - Watch Preset Row

struct WatchPresetRow: View {
    let preset: PresetTimer
    let isSelected: Bool
    let action: () -> Void

    /// Short names for Watch where horizontal space is limited (W-GL-04).
    private var watchName: String {
        switch preset.name {
        case String(localized: "Recommended"): return String(localized: "Rec.")
        default: return preset.name
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: preset.systemImage)
                    .font(.callout)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 18)

                Text(watchName)
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                Text(preset.formattedDuration)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .fixedSize()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.brand)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.name), \(preset.formattedDuration)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Double-tap to select this preset")
    }
}
