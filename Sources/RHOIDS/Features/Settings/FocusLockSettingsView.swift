import SwiftUI
import FamilyControls

struct FocusLockSettingsView: View {
    var screenTimeService: ScreenTimeService
    @AppStorage(
        FocusLockPreferences.modeKey,
        store: UserDefaults(suiteName: SharedStateKeys.suiteName)
    ) private var mode: FocusLockMode = .phoneFree
    @AppStorage(
        FocusLockPreferences.enabledKey,
        store: UserDefaults(suiteName: SharedStateKeys.suiteName)
    ) private var isEnabled = false
    @AppStorage(
        FocusLockPreferences.cooldownDurationKey,
        store: UserDefaults(suiteName: SharedStateKeys.suiteName)
    ) private var cooldownDuration: TimeInterval = FocusLockPreferences.defaultCooldownDuration

    @State private var showingAuthError = false
    @State private var authErrorMessage = ""

    private var isLimitedScrolling: Bool { mode == .limitedScrolling }

    var body: some View {
        Section {
            Picker("Bathroom Mode", selection: $mode) {
                Text("Phone-Free").tag(FocusLockMode.phoneFree)
                Text("Limited Scrolling").tag(FocusLockMode.limitedScrolling)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, newValue in
                if newValue == .limitedScrolling {
                    enableFocusLock()
                } else {
                    disableFocusLock()
                }
            }

            if isLimitedScrolling {
                NavigationLink {
                    FocusLockAppPickerView(screenTimeService: screenTimeService)
                } label: {
                    HStack {
                        Text("Blocked Apps")
                        Spacer()
                        Text(appCountLabel)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Cooldown", selection: $cooldownDuration) {
                    Text("5 minutes").tag(TimeInterval(300))
                    Text("10 minutes").tag(TimeInterval(600))
                    Text("15 minutes").tag(TimeInterval(900))
                    Text("30 minutes").tag(TimeInterval(1800))
                }
                .onChange(of: cooldownDuration) { _, _ in
                    rescheduleRunningTimerIfNeeded()
                }
            }
        } header: {
            Text("Bathroom Mode")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if isLimitedScrolling {
                    Text("During your timer, your chosen apps stay open. When it ends, they're blocked for the cooldown period. You can always unlock early from the Timer tab.")
                    if !isEnabled {
                        Text("Screen Time access is needed to actually block apps. Switch to Phone-Free and back to retry, or grant access in Settings \u{2192} Screen Time.")
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("We'll remind you to put your phone down when the timer starts. No Screen Time access needed.")
                }
                Text("Changes take effect immediately, even for a timer that's already running.")
                    .foregroundStyle(.secondary)
            }
        }
        .alert("Authorization Failed", isPresented: $showingAuthError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authErrorMessage)
        }
    }

    private var appCountLabel: String {
        let count = screenTimeService.selection.applicationTokens.count
            + screenTimeService.selection.categoryTokens.count
        if count == 0 { return String(localized: "None") }
        return String(localized: "\(count) selected")
    }

    private func enableFocusLock() {
        Task {
            do {
                try await screenTimeService.requestAuthorization()
                isEnabled = true
                FocusLockPreferences.shared.isEnabled = true
            } catch {
                isEnabled = false
                FocusLockPreferences.shared.isEnabled = false
                authErrorMessage = String(localized: "Screen Time authorization was denied. You can enable it later in Settings \u{2192} Screen Time.")
                showingAuthError = true
            }
            rescheduleRunningTimerIfNeeded()
        }
    }

    /// Switching to Phone-Free mid-session (or disabling Screen Time access
    /// failed) must immediately stand down any in-flight blocking - an
    /// explicit opt-out should never be silently delayed until the running
    /// timer's original end time.
    private func disableFocusLock() {
        isEnabled = false
        FocusLockPreferences.shared.isEnabled = false
        screenTimeService.removeShields()
        screenTimeService.stopBathroomSessionMonitoring()
        rescheduleRunningTimerIfNeeded()
    }

    /// Re-resolves and re-schedules a currently running timer's end-of-timer
    /// side effects (AlarmKit alert, completion notification, app blocking)
    /// so an explicit mid-session change to Bathroom Mode, app selection, or
    /// cooldown takes effect immediately rather than only for the next
    /// timer. No-ops if nothing is running.
    private func rescheduleRunningTimerIfNeeded() {
        Task { @MainActor in
            await AppServices.shared?.timerService.rescheduleForFocusLockChange()
        }
    }
}
