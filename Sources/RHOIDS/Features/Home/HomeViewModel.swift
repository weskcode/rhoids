import Foundation
import SwiftUI

@Observable
@MainActor
final class HomeViewModel {
    static let minDuration: TimeInterval = 60
    static let maxDuration: TimeInterval = 30 * 60
    static let defaultDuration: TimeInterval = 180

    var selectedPreset: PresetTimer?

    var customDuration: TimeInterval {
        didSet {
            let clamped = min(max(customDuration, Self.minDuration), Self.maxDuration)
            if clamped != customDuration {
                customDuration = clamped
                return
            }
            defaults.set(customDuration, forKey: UserPreferences.lastCustomDurationKey)
        }
    }

    var customMinutes: Int {
        get { Int(customDuration / 60) }
        set { customDuration = TimeInterval(newValue) * 60 }
    }

    var shouldShowTimer = false

    /// True while `startTimer()` is mid-flight, so the event observer doesn't
    /// preempt the local start's reveal animation by setting
    /// `shouldShowTimer` first.
    @ObservationIgnored
    private var isStartingLocally = false

    private(set) var services: AppServices

    @ObservationIgnored
    private let defaults: UserDefaults

    var startPreset: PresetTimer {
        selectedPreset ?? PresetPreferences.defaultPreset
    }

    init(services: AppServices, defaults: UserDefaults = .standard) {
        self.services = services
        self.defaults = defaults
        let stored = defaults.double(forKey: UserPreferences.lastCustomDurationKey)
        let valid = (Self.minDuration...Self.maxDuration).contains(stored)
        self.customDuration = valid ? stored : Self.defaultDuration
    }

    func checkPendingTimer() async {
        guard !shouldShowTimer else { return }
        let state = services.sharedStateService.getTimerState()
        shouldShowTimer = state.isRunning && state.endDate != nil
    }

    /// Presents the running-timer screen when a timer starts outside this
    /// view - from the Watch, a Siri shortcut, or the notification snooze
    /// action - while the app is already open. `TimerService` finishes its
    /// event streams after each terminal event, so re-subscribe in a loop.
    func observeRemoteTimerStarts() async {
        while !Task.isCancelled {
            for await event in await services.timerService.eventStream() {
                if case .started = event, !isStartingLocally, !shouldShowTimer {
                    shouldShowTimer = true
                }
            }
        }
    }

    @discardableResult
    func startTimer(presentTimer: Bool = true) async -> Bool {
        isStartingLocally = true
        defer { isStartingLocally = false }
        let preset = startPreset
        let duration = preset.isCustom ? customDuration : preset.duration

        if UserPreferences.timerAlertsEnabled {
            _ = await services.notificationPermissionService.requestPermission(
                using: services.notificationService
            )
            // Request AlarmKit too so the timer fires a system-level full-screen
            // alarm even when the user is in another app. Silently fails if denied;
            // we fall back to a regular notification.
            _ = await services.alarmKitService.requestAuthorization()
        }
        let prefs = TimerService.TimerPreferences.current()
        await services.timerService.start(duration: duration, preset: preset, preferences: prefs)
        if presentTimer {
            shouldShowTimer = true
        }
        return true
    }
}
