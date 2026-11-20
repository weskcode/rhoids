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
#if DEBUG
    @State private var demoLaunched = false
#endif

    @AppStorage(PresetPreferences.defaultPresetKey) private var defaultPresetID = ""
    @AppStorage(UserPreferences.hapticsEnabledKey) private var hapticsEnabled = true

    private var defaultPreset: PresetTimer {
        PresetTimer.all.first { $0.id.uuidString == defaultPresetID } ?? .recommended
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    heroStartButton

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
            let env = ProcessInfo.processInfo.environment
            guard !demoLaunched else { return }
            demoLaunched = true
            // Wait for the first frame so the push does not block scene activation.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if let seconds = env["RHOIDS_DEMO_SECONDS"].flatMap(TimeInterval.init) {
                    // A short run so the Time's Up screen can be captured.
                    startTimer(duration: seconds)
                } else if env["RHOIDS_DEMO_TIMER"] == "1" {
                    startTimer()
                } else if env["RHOIDS_DEMO_SCREEN"] == "custom" {
                    showCustomPicker = true
                }
            }
#endif
        }
    }

    // MARK: - Hero Start Button (W-GL-01, W-NV-05)

    private var heroStartButton: some View {
        Button(action: { startTimer() }) {
            VStack(spacing: 2) {
                Label("START", systemImage: "play.fill")
                    .font(.headline)

                if selectedPreset.duration > 0 {
                    Text("\(selectedPreset.name) \u{00B7} \(selectedPreset.formattedDuration)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
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

    private func startTimer(duration: TimeInterval? = nil) {
        let duration = duration ?? selectedPreset.duration
        guard duration > 0 else { return }

        let endDate = Date().addingTimeInterval(duration)
        presentTimer(
            endDate: endDate,
            duration: duration,
            presetName: selectedPreset.name,
            presetIcon: selectedPreset.systemImage
        )

        Task {
            await appState.timerService.start(duration: duration, preset: selectedPreset)
        }
    }

    private func presentTimer(
        endDate: Date,
        duration: TimeInterval,
        presetName: String,
        presetIcon: String,
        elapsed: TimeInterval = 0
    ) {
        let vm = WatchTimerViewModel(timerService: appState.timerService)
        // Set initial state synchronously to avoid race with the event stream.
        vm.endDate = endDate
        vm.plannedDuration = duration
        vm.presetName = presetName
        vm.presetIcon = presetIcon
        vm.elapsed = elapsed

        timerVM = vm
        appState.showTimer = true
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
            case .timerStarted(let endDate, let presetName, let duration, let runID, let sentAt):
                let preset = PresetTimer.all.first { $0.name == presetName } ?? .recommended
                Task {
                    let adopted = await appState.timerService.adopt(
                        endDate: endDate,
                        presetName: presetName,
                        duration: duration,
                        remoteRunID: runID,
                        sentAt: sentAt
                    )
                    if adopted, !appState.showTimer || timerVM == nil {
                        presentTimer(
                            endDate: endDate,
                            duration: duration,
                            presetName: presetName,
                            presetIcon: preset.systemImage,
                            elapsed: max(duration - endDate.timeIntervalSinceNow, 0)
                        )
                    }
                }

            case .timerCancelled(let runID, _):
                Task { await appState.timerService.cancelFromPhone(runID: runID) }

            case .timerCompleted(let presetName, let duration, let runID, _):
                Task {
                    await appState.timerService.completeFromPhone(
                        presetName: presetName,
                        duration: duration,
                        runID: runID
                    )
                }

            case .stateResponse(let endDate, let isRunning, let presetName, let duration, let runID, let sentAt):
                if isRunning, let endDate, endDate > Date() {
                    let resolvedName = presetName ?? PresetTimer.recommended.name
                    let preset = PresetTimer.all.first { $0.name == resolvedName } ?? .recommended
                    Task {
                        let adopted = await appState.timerService.adopt(
                            endDate: endDate,
                            presetName: resolvedName,
                            duration: duration,
                            remoteRunID: runID,
                            sentAt: sentAt
                        )
                        if adopted, !appState.showTimer || timerVM == nil {
                            presentTimer(
                                endDate: endDate,
                                duration: duration,
                                presetName: resolvedName,
                                presetIcon: preset.systemImage,
                                elapsed: max(duration - endDate.timeIntervalSinceNow, 0)
                            )
                        }
                    }
                } else {
                    Task {
                        await appState.timerService.reconcileInactivePhoneState(phoneResponseSentAt: sentAt)
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
