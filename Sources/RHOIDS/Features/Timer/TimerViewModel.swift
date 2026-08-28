import Foundation
import SwiftUI
import SwiftData
import os.log

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "TimerViewModel")

@Observable
@MainActor
final class TimerViewModel {
    var elapsed: TimeInterval = 0
    var outcome: TimerOutcome?
    var shouldDismiss = false
    var endDate: Date = .distantFuture
    var startDate: Date = Date()
    var plannedDuration: TimeInterval = 0
    var presetName: String = ""
    var presetIcon: String = ""
    var isCountdownFrozen = false
    var frozenRemaining: TimeInterval?

    private let timerService: TimerService
    private let alarmPlayer: AlarmPlayer
    private let sharedStateService: SharedStateService
    private let liveActivityService: LiveActivityService
    private let alarmKitService: AlarmKitService
    private let screenTimeService: any ScreenTimeShielding
    private let focusLockPreferences: FocusLockPreferences
    private let reviewPromptService: ReviewPromptService
    private var modelContext: ModelContext?
    private var recordedSuccessfulTimer = false

    @ObservationIgnored
    private var observerTask: Task<Void, Never>?

    @ObservationIgnored
    private var completionCleanupTask: Task<Void, Never>?

    init(timerService: TimerService, alarmPlayer: AlarmPlayer, sharedStateService: SharedStateService,
         liveActivityService: LiveActivityService, alarmKitService: AlarmKitService,
         screenTimeService: any ScreenTimeShielding = ScreenTimeService(),
         focusLockPreferences: FocusLockPreferences = .shared,
         reviewPromptService: ReviewPromptService = ReviewPromptService()) {
        self.timerService = timerService
        self.alarmPlayer = alarmPlayer
        self.sharedStateService = sharedStateService
        self.liveActivityService = liveActivityService
        self.alarmKitService = alarmKitService
        self.screenTimeService = screenTimeService
        self.focusLockPreferences = focusLockPreferences
        self.reviewPromptService = reviewPromptService
    }

    isolated deinit {
        observerTask?.cancel()
        completionCleanupTask?.cancel()
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    func startObserving() {
        guard observerTask == nil else { return }
        observerTask = Task { [weak self] in
            await self?.observeTimer()
        }
    }

    func stopObserving() {
        observerTask?.cancel()
        observerTask = nil
    }

    func stopTimer() {
        freezeCountdown()
        Task { await timerService.stop() }
    }

    /// Called from the sheet's onDismiss after the user taps Dismiss.
    /// Stops the looping alarm, dismisses the Live Activity and AlarmKit
    /// alert, then triggers the parent view to dismiss.
    func completionDismissed() {
        guard completionCleanupTask == nil, !shouldDismiss else { return }
        let player = alarmPlayer
        let liveActivity = liveActivityService
        let alarmKit = alarmKitService
        let sharedState = sharedStateService
        completionCleanupTask = Task { [weak self] in
            await player.stopAlarm()
            await liveActivity.dismiss()
            await alarmKit.cancelActive()
            sharedState.clearTimer()
            guard let self, !Task.isCancelled else { return }
            if self.recordedSuccessfulTimer {
                self.reviewPromptService.prepareReviewRequestIfEligible()
            }
            self.shouldDismiss = true
            self.completionCleanupTask = nil
        }
    }

    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        return min(max(elapsed / plannedDuration, 0), 1)
    }

    /// Caption shown under the running timer, reflecting which bathroom-mode
    /// path is active - Phone-Free tells the user to put the phone down;
    /// Limited Scrolling clarifies apps stay open until the timer ends.
    var focusModeCaption: String {
        switch focusLockPreferences.mode {
        case .phoneFree:
            return String(localized: "Put your phone down.")
        case .limitedScrolling:
            return String(localized: "Enjoy your apps. They lock when time's up.")
        }
    }

    var safeEndDate: Date {
        max(endDate, Date())
    }

    private func logSession(wasInterrupted: Bool) {
        guard let modelContext, plannedDuration > 0 else {
            return
        }
        // A timer can never run past its planned end. When completion is
        // detected late (app suspended or relaunched days after the timer
        // expired), "now" is long after the session really ended - record
        // the planned end instead so a stale timer can't log a multi-day
        // session.
        let plannedEnd = startDate.addingTimeInterval(plannedDuration)
        let session = TimerSession(
            startedAt: startDate,
            plannedDuration: plannedDuration,
            endedAt: min(Date(), plannedEnd),
            wasInterrupted: wasInterrupted,
            presetName: presetName
        )
        modelContext.insert(session)
        do {
            try modelContext.save()
        } catch {
            log.error("failed to save timer session: \(error)")
        }
    }

    private func syncCurrentState() async {
        let state = await timerService.timerState()

        guard let currentEnd = state.endDate, let currentPreset = state.preset, state.duration > 0 else { return }
        isCountdownFrozen = false
        frozenRemaining = nil
        endDate = currentEnd
        startDate = currentEnd.addingTimeInterval(-state.duration)
        plannedDuration = state.duration
        presetName = currentPreset.name
        presetIcon = currentPreset.systemImage
        elapsed = max(state.duration - currentEnd.timeIntervalSinceNow, 0)
    }

    /// Detects timers that completed while the app was not active and
    /// surfaces the completion sheet so the user can dismiss the alarm.
    /// Used when the widget started a timer and the app is opened later.
    private func tryRecoverCompletion() async {
        guard outcome == nil else { return }
        let state = sharedStateService.getTimerState()
        guard state.isRunning,
              let recoveredEndDate = state.endDate,
              recoveredEndDate <= Date() else { return }

        let preset = PresetTimer.all.first { $0.name == state.presetName } ?? .recommended
        plannedDuration = state.duration
        presetName = preset.name
        presetIcon = preset.systemImage
        endDate = recoveredEndDate
        startDate = recoveredEndDate.addingTimeInterval(-state.duration)
        elapsed = state.duration
        isCountdownFrozen = true
        frozenRemaining = 0

        logSession(wasInterrupted: false)
        recordSuccessfulTimerForReview()
        startCompletionAlarmIfNeeded()
        Task { await alarmKitService.cancelActive() }
        if focusLockPreferences.isEnabled {
            screenTimeService.applyShields()
        }
        outcome = .completed(TimerQuip.randomCompletion())

        sharedStateService.clearTimer()
    }

    private func observeTimer() async {
        // If a widget-started timer is active in shared state, adopt it
        // so this service drives the in-app countdown, beeps, and completion.
        await timerService.adoptSharedStateIfNeeded()
        await syncCurrentState()
        await tryRecoverCompletion()

        for await event in await timerService.eventStream() {
            switch event {
            case .started(let date, let preset, let duration):
                isCountdownFrozen = false
                frozenRemaining = nil
                endDate = date
                startDate = Date()
                plannedDuration = duration
                presetName = preset.name
                presetIcon = preset.systemImage
                elapsed = 0
            case .tick:
                break
            case .completed:
                guard outcome == nil else {
                    continue
                }
                freezeCountdown(elapsedOverride: plannedDuration)
                logSession(wasInterrupted: false)
                recordSuccessfulTimerForReview()
                // Only play the in-app alarm loop when the app is actively
                // in the foreground. When backgrounded, AlarmKit (or the
                // fallback notification) already alerted the user - starting
                // the loop here would buzz indefinitely with no visible UI
                // to dismiss it.
                if UIApplication.shared.applicationState == .active {
                    startCompletionAlarmIfNeeded()
                    Task { await alarmKitService.cancelActive() }
                }
                if focusLockPreferences.isEnabled {
                    screenTimeService.applyShields()
                }
                outcome = .completed(TimerQuip.randomCompletion())
            case .cancelled:
                guard outcome == nil else {
                    continue
                }
                freezeCountdown()
                logSession(wasInterrupted: true)
                outcome = .stoppedEarly(TimerQuip.randomEarlyStop())
            }
        }
    }

    private func freezeCountdown(elapsedOverride: TimeInterval? = nil) {
        let frozenElapsed = elapsedOverride ?? min(max(Date().timeIntervalSince(startDate), 0), plannedDuration)
        elapsed = frozenElapsed
        frozenRemaining = max(plannedDuration - frozenElapsed, 0)
        isCountdownFrozen = true
    }

    private func startCompletionAlarmIfNeeded() {
        guard UserPreferences.timerAlertsEnabled else { return }
        let player = alarmPlayer
        let sound = SoundPreferences.alarm
        let haptics = UserPreferences.timerAlertHapticsEnabled
        Task { await player.startAlarmLoop(sound: sound, withHaptic: haptics) }
    }

    private func recordSuccessfulTimerForReview() {
        guard !recordedSuccessfulTimer else { return }
        recordedSuccessfulTimer = true
        reviewPromptService.recordSuccessfulTimer()
    }
}
