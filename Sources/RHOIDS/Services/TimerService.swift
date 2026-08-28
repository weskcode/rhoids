import Foundation
import FamilyControls
import os.log

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "TimerService")

enum TimerEvent: Sendable {
    case started(endDate: Date, preset: PresetTimer, duration: TimeInterval)
    case tick(remaining: TimeInterval)
    case completed(preset: PresetTimer?, duration: TimeInterval)
    case cancelled
}

actor TimerService {
    private var countdownTask: Task<Void, Never>?
    /// Tracks the in-flight AlarmKit/notification/shared-state scheduling
    /// (or, for adopted timers, its full side-effect setup) started by
    /// `start()`/`adopt()`. Every cancellation entry point must cancel *and
    /// await* this before issuing its own external cancel calls - actor
    /// reentrancy means a scheduling call can still be mid-flight when a
    /// concurrent `stop()` runs, and only awaiting it guarantees the
    /// cancellation is the last writer instead of racing ahead of a
    /// schedule that lands moments later.
    private var sideEffectsTask: Task<Void, Never>?
    private var listeners: [UUID: AsyncStream<TimerEvent>.Continuation] = [:]
    private var activeRunID: UUID?
    private var isPreparingTimer = false

    private(set) var currentEndDate: Date?
    private(set) var currentPreset: PresetTimer?
    private(set) var currentDuration: TimeInterval = 0
    var isRunning: Bool { countdownTask != nil || isPreparingTimer }

    private let notificationService: NotificationService
    private let liveActivityService: LiveActivityService
    private let sharedStateService: SharedStateService
    private let alarmPlayer: AlarmPlayer
    private let alarmKitService: AlarmKitService
    private let screenTimeSessionScheduling: any ScreenTimeSessionScheduling
    private let sideEffectsEnabled: Bool

    init(notificationService: NotificationService,
         liveActivityService: LiveActivityService,
         sharedStateService: SharedStateService,
         alarmPlayer: AlarmPlayer,
         alarmKitService: AlarmKitService,
         screenTimeSessionScheduling: any ScreenTimeSessionScheduling,
         sideEffectsEnabled: Bool = true) {
        self.notificationService = notificationService
        self.liveActivityService = liveActivityService
        self.sharedStateService = sharedStateService
        self.alarmPlayer = alarmPlayer
        self.alarmKitService = alarmKitService
        self.screenTimeSessionScheduling = screenTimeSessionScheduling
        self.sideEffectsEnabled = sideEffectsEnabled
        log.debug("initialized")
    }

    func eventStream() -> AsyncStream<TimerEvent> {
        let id = UUID()
        log.debug("creating event stream for listener \(id.uuidString.prefix(8))")
        let (stream, continuation) = AsyncStream.makeStream(of: TimerEvent.self)
        listeners[id] = continuation
        continuation.onTermination = { [id] _ in
            log.debug("listener \(id.uuidString.prefix(8)) terminated")
            Task { await self.removeListener(id: id) }
        }
        return stream
    }

    func timerState() -> (endDate: Date?, isRunning: Bool, preset: PresetTimer?, duration: TimeInterval) {
        (currentEndDate, isRunning, currentPreset, currentDuration)
    }

    private func removeListener(id: UUID) {
        listeners.removeValue(forKey: id)
    }

    private func broadcast(_ event: TimerEvent) {
        if case .tick = event {
            // Ticks arrive every second, so avoid flooding the console.
        } else {
            log.debug("broadcasting \(String(describing: event)) to \(self.listeners.count) listener(s)")
        }
        for continuation in listeners.values {
            continuation.yield(event)
        }
    }

    /// Yields a terminal event, then finishes all continuations so
    /// consumers' `for await` loops end and listeners are cleaned up.
    private func broadcastTerminal(_ event: TimerEvent) {
        broadcast(event)
        let count = listeners.count
        for continuation in listeners.values {
            continuation.finish()
        }
        listeners.removeAll()
        log.debug("finished \(count) listener(s) after terminal event")
    }

    struct TimerPreferences: Sendable {
        var notificationsEnabled: Bool = true
        var warningEnabled: Bool = true
        var warningMode: WarningMode = .endOnly
        var hapticsEnabled: Bool = true
        var alarmSound: AlarmSound = .systemDefault
        var warningSound: AlarmSound = .systemDefault
        var focusLockMode: FocusLockMode = .phoneFree
        /// Whether Limited Scrolling will actually shield apps at completion
        /// - false (even when `focusLockMode == .limitedScrolling`) if Screen
        /// Time isn't authorized or no apps are selected. Notification/alarm
        /// copy must key off this, not the raw mode, so we never tell the
        /// user apps are blocked when nothing will actually block them.
        var focusLockBlockingWillEngage: Bool = false
        var focusLockCooldownMinutes: Int = 5

        @MainActor
        static func current(warningEnabled warningOverride: Bool? = nil) -> TimerPreferences {
            let focusPrefs = FocusLockPreferences.shared
            let mode = focusPrefs.mode
            let hasSelection = focusPrefs.selection.map {
                !$0.applicationTokens.isEmpty || !$0.categoryTokens.isEmpty
            } ?? false
            let blockingWillEngage = mode == .limitedScrolling
                && focusPrefs.isEnabled
                && hasSelection
                && AuthorizationCenter.shared.authorizationStatus == .approved

            return TimerPreferences(
                notificationsEnabled: UserPreferences.notificationsEnabled,
                warningEnabled: warningOverride ?? UserPreferences.warningEnabled,
                warningMode: UserPreferences.warningMode,
                hapticsEnabled: UserPreferences.hapticsEnabled,
                alarmSound: SoundPreferences.alarm,
                warningSound: SoundPreferences.warning,
                focusLockMode: mode,
                focusLockBlockingWillEngage: blockingWillEngage,
                focusLockCooldownMinutes: max(1, Int((focusPrefs.cooldownDuration / 60).rounded()))
            )
        }

        var timerAlertsEnabled: Bool {
            notificationsEnabled
        }

        var timerWarningEnabled: Bool {
            timerAlertsEnabled && warningEnabled
        }

        var timerAlertHapticsEnabled: Bool {
            timerAlertsEnabled && hapticsEnabled
        }
    }

    func start(duration: TimeInterval, preset: PresetTimer, preferences: TimerPreferences = TimerPreferences()) async {
        log.debug("start() called - duration=\(duration)s, preset=\(preset.name), listeners=\(self.listeners.count)")
        countdownTask?.cancel()
        countdownTask = nil
        sideEffectsTask?.cancel()
        await sideEffectsTask?.value
        sideEffectsTask = nil
        let runID = UUID()
        activeRunID = runID
        isPreparingTimer = true
        let endDate = Date().addingTimeInterval(duration)

        currentEndDate = endDate
        currentPreset = preset
        currentDuration = duration

        // Start the Live Activity EAGERLY before broadcasting - this ensures
        // the Dynamic Island is registered with the system before the user
        // can background the app. On physical devices the system can suspend
        // the app within seconds of backgrounding; a fire-and-forget Task
        // may never reach Activity.request() in time.
        if sideEffectsEnabled {
            do {
                try await liveActivityService.start(preset: preset, duration: duration, endDate: endDate)
            } catch {
                log.error("Live Activity failed (non-fatal): \(error)")
            }
        }

        // Actor reentrancy allows stop() or another start() to run while the
        // Live Activity request is suspended. Never let obsolete start work
        // publish state or install tasks for a timer that has been replaced.
        guard activeRunID == runID, !Task.isCancelled else {
            log.debug("start abandoned after Live Activity setup because its run is no longer active")
            return
        }

        broadcast(.started(endDate: endDate, preset: preset, duration: duration))

        isPreparingTimer = false
        startCountdownTask(
            runID: runID,
            endDate: endDate,
            preset: preset,
            duration: duration,
            beepsEnabled: preferences.timerWarningEnabled,
            warningMode: preferences.warningMode,
            hapticsEnabled: preferences.timerAlertHapticsEnabled,
            player: alarmPlayer
        )

        if sideEffectsEnabled {
            sideEffectsTask = Task {
                await self.prepareRemainingTimerSideEffects(
                    runID: runID,
                    endDate: endDate,
                    preset: preset,
                    duration: duration,
                    preferences: preferences
                )
            }
        }
    }

    private func prepareRemainingTimerSideEffects(
        runID: UUID,
        endDate: Date,
        preset: PresetTimer,
        duration: TimeInterval,
        preferences: TimerPreferences
    ) async {
        let tag = runID.uuidString.prefix(8)
        guard activeRunID == runID, !Task.isCancelled else { return }

        log.debug("[\(tag)] setting shared state...")
        await sharedStateService.setTimer(endDate: endDate, presetName: preset.name, duration: duration)
        log.debug("[\(tag)] shared state set ✓")
        guard activeRunID == runID, !Task.isCancelled else { return }

        if preferences.focusLockBlockingWillEngage {
            log.debug("[\(tag)] starting bathroom session monitoring...")
            await screenTimeSessionScheduling.startBathroomSessionMonitoring(duration: duration)
        }
        guard activeRunID == runID, !Task.isCancelled else { return }

        let messagingMode = resolvedMessagingMode(preferences)

        let alarmKitHandling: Bool
        if preferences.timerAlertsEnabled {
            log.debug("[\(tag)] scheduling AlarmKit...")
            let alarmKitID = await alarmKitService.scheduleTimer(
                duration: duration,
                presetName: preset.name,
                messagingMode: messagingMode,
                cooldownMinutes: preferences.focusLockCooldownMinutes
            )
            alarmKitHandling = alarmKitID != nil
            log.debug("[\(tag)] AlarmKit done ✓ (id=\(alarmKitID?.uuidString.prefix(8) ?? "nil"), handling=\(alarmKitHandling))")
        } else {
            alarmKitHandling = false
            log.debug("[\(tag)] AlarmKit skipped - timer alerts disabled")
        }
        guard activeRunID == runID, !Task.isCancelled else { return }

        if preferences.timerAlertsEnabled {
            log.debug("[\(tag)] scheduling notifications...")
            await notificationService.schedule(
                endDate: endDate,
                presetName: preset.name,
                warningEnabled: preferences.timerWarningEnabled,
                alarmSound: preferences.alarmSound,
                warningSound: preferences.warningSound,
                includeCompletion: !alarmKitHandling,
                messagingMode: messagingMode,
                cooldownMinutes: preferences.focusLockCooldownMinutes
            )
            if preferences.timerWarningEnabled && preferences.warningMode == .recurring {
                await notificationService.scheduleBeepNotifications(
                    duration: duration,
                    endDate: endDate,
                    sound: preferences.warningSound
                )
            }
            if preferences.focusLockMode == .phoneFree {
                await notificationService.scheduleStartReminder(mode: .phoneFree)
            }
            log.debug("[\(tag)] notifications scheduled ✓")
        }
    }

    /// Resolves the mode that should actually drive completion messaging -     /// falls back to `nil` (today's neutral default copy) when Limited
    /// Scrolling was picked but blocking won't really engage.
    private func resolvedMessagingMode(_ preferences: TimerPreferences) -> FocusLockMode? {
        FocusLockMode.effective(selected: preferences.focusLockMode, blockingWillEngage: preferences.focusLockBlockingWillEngage)
    }

    private func startCountdownTask(
        runID: UUID,
        endDate: Date,
        preset: PresetTimer,
        duration: TimeInterval,
        beepsEnabled: Bool,
        warningMode: WarningMode = .endOnly,
        hapticsEnabled: Bool,
        player: AlarmPlayer
    ) {
        countdownTask = Task {
            // End-only: single beep at T-30. Recurring: beep at every 30s boundary.
            var nextBeepAt: TimeInterval
            if warningMode == .endOnly {
                nextBeepAt = min(30, duration)
            } else {
                nextBeepAt = floor(duration / 30) * 30
                if nextBeepAt >= duration { nextBeepAt -= 30 }
            }
            log.debug("beep schedule: first beep at \(nextBeepAt)s remaining (duration=\(duration)s, mode=\(warningMode.rawValue), haptics=\(hapticsEnabled))")

            var naturalCompletion = false
            while !Task.isCancelled {
                guard activeRunID == runID else { break }
                let remaining = endDate.timeIntervalSince(Date())
                if remaining <= 0 {
                    naturalCompletion = true
                    break
                }

                if nextBeepAt > 0, remaining <= nextBeepAt {
                    log.debug("30s boundary crossed - \(Int(nextBeepAt))s mark, remaining=\(String(format: "%.1f", remaining))s")
                    if beepsEnabled {
                        await player.playWarningBeep(withHaptic: hapticsEnabled)
                    }
                    if warningMode == .recurring {
                        nextBeepAt -= 30
                    } else {
                        nextBeepAt = 0
                    }
                }

                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
            }

            if naturalCompletion, activeRunID == runID {
                await handleTimerComplete(preset: preset, duration: duration)
            } else if activeRunID == runID {
                log.debug("countdown task ended early (cancelled) - skipping completion")
            }
        }
    }

    /// If shared state shows an active timer that this service didn't start
    /// (typical case: widget tapped `StartDefaultTimerIntent` and opened the app),
    /// adopt it - populate local state, start the Live Activity + notifications +
    /// AlarmKit alarm, and kick off the countdown task.
    func adoptSharedStateIfNeeded() async {
        guard countdownTask == nil, !isPreparingTimer else {
            log.debug("adopt skipped - already running locally")
            return
        }

        let state = sharedStateService.getTimerState()
        guard state.isRunning,
              let sharedEndDate = state.endDate,
              sharedEndDate > Date() else {
            return
        }

        let preset = PresetTimer.all.first { $0.name == state.presetName } ?? .recommended
        await adopt(endDate: sharedEndDate, preset: preset, duration: state.duration)
    }

    /// Adopt a timer that is already running elsewhere (widget-started via
    /// shared state, or Watch-started via WatchConnectivity), preserving its
    /// original `endDate` so both devices stay in lockstep. Replaces any
    /// locally running timer - the adopted timer is the user's most recent
    /// explicit start. Expired timers (e.g. a queued WatchConnectivity
    /// message delivered long after the fact) are ignored.
    func adopt(endDate: Date, preset: PresetTimer, duration: TimeInterval) async {
        let remaining = endDate.timeIntervalSince(Date())
        guard remaining > 0 else {
            log.debug("adopt skipped - timer already expired (\(String(format: "%.0f", remaining))s)")
            return
        }

        log.debug("adopting timer - endDate=\(endDate), preset=\(preset.name), duration=\(duration)s, remaining=\(String(format: "%.0f", remaining))s")

        countdownTask?.cancel()
        countdownTask = nil
        sideEffectsTask?.cancel()
        await sideEffectsTask?.value
        sideEffectsTask = nil
        let runID = UUID()
        activeRunID = runID
        isPreparingTimer = true
        currentEndDate = endDate
        currentPreset = preset
        currentDuration = duration

        broadcast(.started(endDate: endDate, preset: preset, duration: duration))

        // Read user preferences for the services we're about to start.
        let adoptedPreferences = await TimerPreferences.current()
        let adoptedBeepsEnabled = adoptedPreferences.timerWarningEnabled

        if sideEffectsEnabled {
            // Start the Live Activity so the Dynamic Island / Lock Screen show the timer.
            // Awaited eagerly (like `start()`) rather than folded into the
            // tracked side-effects task: LiveActivityService is idempotent -             // `end()`/`dismiss()` sweep up any orphaned activity even if this
            // races with a cancellation - so it isn't part of the
            // "cancelled timer still alerts" hazard the tracked task guards
            // against below.
            try? await liveActivityService.start(preset: preset, duration: duration, endDate: endDate)

            // AlarmKit, notifications, and shared state are irreversible
            // external registrations, so they're scheduled in a tracked,
            // cancellable/awaitable task. Every teardown entry point cancels
            // and awaits this task *before* issuing its own cancel calls, so
            // a concurrent stop/completion can never race ahead of a
            // schedule that's still landing.
            sideEffectsTask = Task {
                await self.prepareAdoptedTimerSideEffects(
                    runID: runID,
                    endDate: endDate,
                    duration: duration,
                    remaining: remaining,
                    preset: preset,
                    preferences: adoptedPreferences
                )
            }
        }

        let player = alarmPlayer

        guard activeRunID == runID else { return }
        isPreparingTimer = false
        countdownTask = Task {
            let currentRemaining = endDate.timeIntervalSince(Date())
            var nextBeepAt: TimeInterval
            if adoptedPreferences.warningMode == .endOnly {
                nextBeepAt = min(30, currentRemaining)
            } else {
                nextBeepAt = floor(currentRemaining / 30) * 30
                if nextBeepAt >= currentRemaining { nextBeepAt -= 30 }
            }
            log.debug("adopted: first beep at \(nextBeepAt)s remaining (currentRemaining=\(String(format: "%.1f", currentRemaining))s, mode=\(adoptedPreferences.warningMode.rawValue))")

            var naturalCompletion = false
            while !Task.isCancelled {
                guard activeRunID == runID else { break }
                let remaining = endDate.timeIntervalSince(Date())
                if remaining <= 0 {
                    naturalCompletion = true
                    break
                }

                if nextBeepAt > 0, remaining <= nextBeepAt {
                    log.debug("adopted: 30s boundary crossed - \(Int(nextBeepAt))s mark, remaining=\(String(format: "%.1f", remaining))s")
                    if adoptedBeepsEnabled {
                        await player.playWarningBeep(withHaptic: adoptedPreferences.timerAlertHapticsEnabled)
                    }
                    if adoptedPreferences.warningMode == .recurring {
                        nextBeepAt -= 30
                    } else {
                        nextBeepAt = 0
                    }
                }

                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
            }

            if naturalCompletion, activeRunID == runID {
                await handleTimerComplete(preset: preset, duration: duration)
            } else if activeRunID == runID {
                log.debug("adopted countdown task ended early (cancelled) - skipping completion")
            }
        }
    }

    /// Schedules AlarmKit, notifications, and shared state for an adopted
    /// timer. Mirrors `prepareRemainingTimerSideEffects` - every irreversible
    /// external call is preceded by a fresh `activeRunID` check so a teardown
    /// that lands mid-flight (from `stop()`, natural completion, or
    /// `handleExternalAlarmStop()`, all of which cancel-and-await this task)
    /// stops further scheduling instead of arming an alert nobody can reach.
    private func prepareAdoptedTimerSideEffects(
        runID: UUID,
        endDate: Date,
        duration: TimeInterval,
        remaining: TimeInterval,
        preset: PresetTimer,
        preferences: TimerPreferences
    ) async {
        let tag = runID.uuidString.prefix(8)
        guard activeRunID == runID, !Task.isCancelled else { return }

        if preferences.focusLockBlockingWillEngage {
            log.debug("[\(tag)] adopted: starting bathroom session monitoring...")
            await screenTimeSessionScheduling.startBathroomSessionMonitoring(duration: remaining)
        }
        guard activeRunID == runID, !Task.isCancelled else { return }

        let messagingMode = resolvedMessagingMode(preferences)

        // Schedule AlarmKit with remaining time so the alarm fires at the right moment.
        let alarmKitID: UUID?
        if preferences.timerAlertsEnabled {
            log.debug("[\(tag)] adopted: scheduling AlarmKit...")
            alarmKitID = await alarmKitService.scheduleTimer(
                duration: remaining,
                presetName: preset.name,
                messagingMode: messagingMode,
                cooldownMinutes: preferences.focusLockCooldownMinutes
            )
            log.debug("[\(tag)] adopted: AlarmKit done ✓ (id=\(alarmKitID?.uuidString.prefix(8) ?? "nil"))")
        } else {
            alarmKitID = nil
        }
        guard activeRunID == runID, !Task.isCancelled else { return }

        // Schedule notifications; skip completion alert if AlarmKit is handling it.
        if preferences.timerAlertsEnabled {
            log.debug("[\(tag)] adopted: scheduling notifications...")
            await notificationService.schedule(
                endDate: endDate,
                presetName: preset.name,
                warningEnabled: preferences.timerWarningEnabled,
                alarmSound: preferences.alarmSound,
                warningSound: preferences.warningSound,
                includeCompletion: alarmKitID == nil,
                messagingMode: messagingMode,
                cooldownMinutes: preferences.focusLockCooldownMinutes
            )
            // Recurring mode: schedule drop-down banner beeps for adopted timer.
            if preferences.timerWarningEnabled && preferences.warningMode == .recurring {
                await notificationService.scheduleBeepNotifications(
                    duration: remaining,
                    endDate: endDate,
                    sound: preferences.warningSound
                )
            }
            if preferences.focusLockMode == .phoneFree {
                await notificationService.scheduleStartReminder(mode: .phoneFree)
            }
            log.debug("[\(tag)] adopted: notifications scheduled ✓")
        }
        guard activeRunID == runID, !Task.isCancelled else { return }

        // Write shared state so the widget shows the running timer. For a
        // widget-started adoption the values are already there; for a
        // Watch-started adoption this is the first write. Either way the
        // call reloads all widget timelines.
        log.debug("[\(tag)] adopted: setting shared state...")
        await sharedStateService.setTimer(endDate: endDate, presetName: preset.name, duration: duration)
        log.debug("[\(tag)] adopted: shared state set ✓")
    }

    /// Re-resolves Focus Lock's effective mode and re-schedules the
    /// *timer-end* side effects (AlarmKit alert, completion notification,
    /// bathroom-session blocking) for the currently running timer, using its
    /// unchanged `endDate` but freshly read preferences.
    ///
    /// Without this, a timer completes using whichever mode was in effect
    /// when it *started* - but the user may switch Bathroom Mode (or its app
    /// selection/cooldown) in Settings while a timer is already running, and
    /// that explicit mid-session change must not be silently deferred to the
    /// next timer. Call this from Settings whenever any input to the
    /// effective-mode resolution changes.
    ///
    /// No-ops if nothing is currently running. Uses the same cancel-and-await
    /// ordering as `start()`/`stop()` so a concurrent completion or stop
    /// can't race a reschedule that lands moments later, and so this
    /// reschedule can't itself race a `start()`/`adopt()` that's still
    /// mid-flight.
    func rescheduleForFocusLockChange() async {
        guard sideEffectsEnabled,
              let runID = activeRunID,
              let endDate = currentEndDate,
              let preset = currentPreset,
              currentDuration > 0 else {
            log.debug("rescheduleForFocusLockChange skipped - no timer running")
            return
        }
        let remaining = endDate.timeIntervalSince(Date())
        guard remaining > 0 else { return }

        // Let any in-flight start()/adopt() scheduling land first so this
        // reschedule is the last writer, not a competing one.
        await sideEffectsTask?.value
        guard activeRunID == runID else { return }

        let preferences = await TimerPreferences.current()
        let tag = runID.uuidString.prefix(8)
        log.debug("[\(tag)] rescheduling Focus Lock side effects - remaining=\(String(format: "%.0f", remaining))s, mode=\(preferences.focusLockMode.rawValue), engage=\(preferences.focusLockBlockingWillEngage)")

        sideEffectsTask = Task {
            await self.rescheduleTimerEndSideEffects(
                runID: runID,
                endDate: endDate,
                preset: preset,
                remaining: remaining,
                preferences: preferences
            )
        }
    }

    private func rescheduleTimerEndSideEffects(
        runID: UUID,
        endDate: Date,
        preset: PresetTimer,
        remaining: TimeInterval,
        preferences: TimerPreferences
    ) async {
        let tag = runID.uuidString.prefix(8)
        guard activeRunID == runID, !Task.isCancelled else { return }

        // Stand down any previously-scheduled bathroom session monitoring
        // before deciding whether to reschedule it under the new mode - the
        // old schedule may no longer reflect the user's current choice.
        await screenTimeSessionScheduling.stopBathroomSessionMonitoring()
        if preferences.focusLockBlockingWillEngage {
            log.debug("[\(tag)] reschedule: starting bathroom session monitoring...")
            await screenTimeSessionScheduling.startBathroomSessionMonitoring(duration: remaining)
        }
        guard activeRunID == runID, !Task.isCancelled else { return }

        let messagingMode = resolvedMessagingMode(preferences)

        let alarmKitHandling: Bool
        if preferences.timerAlertsEnabled {
            log.debug("[\(tag)] reschedule: scheduling AlarmKit...")
            let alarmKitID = await alarmKitService.scheduleTimer(
                duration: remaining,
                presetName: preset.name,
                messagingMode: messagingMode,
                cooldownMinutes: preferences.focusLockCooldownMinutes
            )
            alarmKitHandling = alarmKitID != nil
        } else {
            alarmKitHandling = false
            await alarmKitService.cancelActive()
        }
        guard activeRunID == runID, !Task.isCancelled else { return }

        if preferences.timerAlertsEnabled {
            log.debug("[\(tag)] reschedule: scheduling notifications...")
            await notificationService.schedule(
                endDate: endDate,
                presetName: preset.name,
                warningEnabled: preferences.timerWarningEnabled,
                alarmSound: preferences.alarmSound,
                warningSound: preferences.warningSound,
                includeCompletion: !alarmKitHandling,
                messagingMode: messagingMode,
                cooldownMinutes: preferences.focusLockCooldownMinutes
            )
            // Re-derive beep boundaries from the remaining time, not the
            // original full duration - mirrors how `adopt()` schedules beeps
            // for a timer that's already partway through.
            if preferences.timerWarningEnabled && preferences.warningMode == .recurring {
                await notificationService.scheduleBeepNotifications(
                    duration: remaining,
                    endDate: endDate,
                    sound: preferences.warningSound
                )
            }
            // Deliberately does NOT re-fire `scheduleStartReminder` - that's
            // a timer-*start* message, not a timer-end one, and re-sending it
            // mid-session on every settings tweak would be spammy/confusing.
        } else {
            await notificationService.cancelAll()
        }
        log.debug("[\(tag)] reschedule complete ✓")
    }

    func stop() async {
        let tag = activeRunID?.uuidString.prefix(8) ?? "nil"
        log.debug("stop() called - runID=\(tag)")
        countdownTask?.cancel()
        countdownTask = nil
        activeRunID = nil
        isPreparingTimer = false
        currentEndDate = nil
        currentPreset = nil
        currentDuration = 0

        // Guarantee cancellation is the last writer: wait for any in-flight
        // scheduling to fully land (or bail via its own guards) before we
        // issue the cancel calls below, so they see the true final state
        // instead of racing ahead of a schedule that completes moments later.
        sideEffectsTask?.cancel()
        await sideEffectsTask?.value
        sideEffectsTask = nil

        if sideEffectsEnabled {
            await alarmKitService.cancelActive()
        }
        await handleCancelled()
    }

    /// The user stopped the system alarm from *outside* the app (e.g. the
    /// Dynamic Island Stop button) while no in-app UI was driving the timer.
    /// Tears down every parallel alert source - Live Activity, looping audio,
    /// pending notifications, and the tracked AlarmKit alarm - so nothing is
    /// left armed to buzz later.
    ///
    /// Deliberately does *not* broadcast `.cancelled`: the timer already
    /// reached its end, so any live consumer must not be told it was
    /// "stopped early". Idempotent and safe to call repeatedly.
    func handleExternalAlarmStop() async {
        let tag = activeRunID?.uuidString.prefix(8) ?? "nil"
        log.debug("handleExternalAlarmStop - runID=\(tag)")
        countdownTask?.cancel()
        countdownTask = nil
        activeRunID = nil
        isPreparingTimer = false
        currentEndDate = nil
        currentPreset = nil
        currentDuration = 0

        // Same ordering guarantee as `stop()`: don't cancel until any
        // in-flight scheduling has fully resolved.
        sideEffectsTask?.cancel()
        await sideEffectsTask?.value
        sideEffectsTask = nil

        guard sideEffectsEnabled else { return }
        await alarmPlayer.stopAlarm()
        await sharedStateService.clearTimer()
        await liveActivityService.end()
        await notificationService.cancelAll()
        await alarmKitService.cancelActive()
        await screenTimeSessionScheduling.stopBathroomSessionMonitoring()
    }

    private func handleTimerComplete(preset: PresetTimer? = nil, duration: TimeInterval = 0) async {
        let tag = activeRunID?.uuidString.prefix(8) ?? "nil"
        log.debug("handleTimerComplete - runID=\(tag), preset=\(preset?.name ?? "nil")")
        countdownTask = nil
        activeRunID = nil
        isPreparingTimer = false
        currentEndDate = nil
        currentPreset = nil
        currentDuration = 0

        // Natural completion can arrive while the start/adopt side-effects
        // task is still inside a system call. Wait for it before cancelling
        // completion notifications so the cancellation remains the final
        // external write.
        sideEffectsTask?.cancel()
        await sideEffectsTask?.value
        sideEffectsTask = nil

        if sideEffectsEnabled {
            await sharedStateService.clearTimer()
        }
        if sideEffectsEnabled {
            await liveActivityService.markComplete()
            await notificationService.cancelTimerAlertsPreservingCooldown()
        }
        // AlarmKit is cancelled by the TimerViewModel: immediately when
        // the app is in the foreground (the in-app alarm takes over), or
        // when the user opens the app and dismisses the completion sheet.
        broadcastTerminal(.completed(preset: preset, duration: duration))
    }

    private func handleCancelled() async {
        log.debug("handleCancelled")
        countdownTask = nil
        activeRunID = nil
        isPreparingTimer = false
        if sideEffectsEnabled {
            await sharedStateService.clearTimer()
            await liveActivityService.end()
            await notificationService.cancelAll()
            await screenTimeSessionScheduling.stopBathroomSessionMonitoring()
        }
        broadcastTerminal(.cancelled)
    }
}
