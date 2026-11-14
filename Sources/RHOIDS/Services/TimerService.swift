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

enum TimerSyncEvent: Sendable {
    case started(runID: UUID, endDate: Date, preset: PresetTimer, duration: TimeInterval, sentAt: Date)
    case completed(runID: UUID, preset: PresetTimer?, duration: TimeInterval, sentAt: Date)
    case cancelled(runID: UUID, sentAt: Date)
}

actor TimerService {
    private static let maxRetiredSyncRunIDs = 64

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
    private var syncListeners: [UUID: AsyncStream<TimerSyncEvent>.Continuation] = [:]
    private var activeRunID: UUID?
    private var syncRunID: UUID?
    private var currentRunStartedAt: Date?
    private var retiredSyncRunIDs: [UUID] = []
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

    func syncEventStream() -> AsyncStream<TimerSyncEvent> {
        let id = UUID()
        log.debug("creating sync event stream for listener \(id.uuidString.prefix(8))")
        let (stream, continuation) = AsyncStream.makeStream(of: TimerSyncEvent.self)
        syncListeners[id] = continuation
        continuation.onTermination = { [id] _ in
            log.debug("sync listener \(id.uuidString.prefix(8)) terminated")
            Task { await self.removeSyncListener(id: id) }
        }
        return stream
    }

    func timerState() -> (endDate: Date?, isRunning: Bool, preset: PresetTimer?, duration: TimeInterval) {
        (currentEndDate, isRunning, currentPreset, currentDuration)
    }

    func syncState() -> (endDate: Date?, isRunning: Bool, preset: PresetTimer?, duration: TimeInterval, runID: UUID?) {
        (currentEndDate, isRunning, currentPreset, currentDuration, syncRunID ?? activeRunID)
    }

    private func removeListener(id: UUID) {
        listeners.removeValue(forKey: id)
    }

    private func removeSyncListener(id: UUID) {
        syncListeners.removeValue(forKey: id)
    }

    private func retireSyncRunID(_ id: UUID?) {
        guard let id else { return }
        if !retiredSyncRunIDs.contains(id) {
            retiredSyncRunIDs.append(id)
            if retiredSyncRunIDs.count > Self.maxRetiredSyncRunIDs {
                retiredSyncRunIDs.removeFirst(retiredSyncRunIDs.count - Self.maxRetiredSyncRunIDs)
            }
        }
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

    private func broadcastSync(_ event: TimerSyncEvent) {
        for continuation in syncListeners.values {
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

    private func broadcastSyncTerminal(_ event: TimerSyncEvent) {
        broadcastSync(event)
        for continuation in syncListeners.values {
            continuation.finish()
        }
        syncListeners.removeAll()
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
        retireSyncRunID(syncRunID ?? activeRunID)
        countdownTask?.cancel()
        countdownTask = nil
        sideEffectsTask?.cancel()
        await sideEffectsTask?.value
        sideEffectsTask = nil
        let runID = UUID()
        let startedAt = Date()
        activeRunID = runID
        syncRunID = runID
        currentRunStartedAt = startedAt
        isPreparingTimer = true
        let endDate = startedAt.addingTimeInterval(duration)

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
        guard activeRunID == runID else {
            log.debug("start abandoned after Live Activity setup because a newer run replaced it")
            return
        }

        // The run is still ours, but the enclosing Task (e.g. a cancelled
        // App Intent / Siri request) was cancelled while the Live Activity
        // request was suspended above. Unlike the newer-run case, nothing
        // else will ever clean this run up - no countdown task or side
        // effects have been scheduled yet - so isPreparingTimer would
        // otherwise stay stuck true forever, permanently blocking
        // adoptSharedStateIfNeeded() and every future start(). Tear down
        // the Live Activity that was already registered and reset state.
        guard !Task.isCancelled else {
            log.debug("start cancelled after Live Activity setup - tearing down the orphaned Live Activity")
            activeRunID = nil
            syncRunID = nil
            currentRunStartedAt = nil
            isPreparingTimer = false
            currentEndDate = nil
            currentPreset = nil
            currentDuration = 0
            if sideEffectsEnabled {
                await liveActivityService.end()
            }
            return
        }

        broadcast(.started(endDate: endDate, preset: preset, duration: duration))
        broadcastSync(.started(runID: runID, endDate: endDate, preset: preset, duration: duration, sentAt: Date()))

        isPreparingTimer = false
        startCountdownTask(
            runID: runID,
            endDate: endDate,
            preset: preset,
            duration: duration,
            initialRemaining: duration,
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

        await applyTimerSideEffects(
            runID: runID,
            endDate: endDate,
            preset: preset,
            alertDuration: duration,
            preferences: preferences,
            stopExistingScreenTimeFirst: false,
            cancelAlertsWhenDisabled: false,
            includeStartReminder: true,
            logPrefix: ""
        )
    }

    /// Shared Screen Time, AlarmKit, and Notification scheduling used across
    /// `start()`, `adopt()`, and `rescheduleForFocusLockChange()`. Every
    /// irreversible external call is preceded by `activeRunID == runID && !Task.isCancelled`.
    private func applyTimerSideEffects(
        runID: UUID,
        endDate: Date,
        preset: PresetTimer,
        alertDuration: TimeInterval,
        preferences: TimerPreferences,
        stopExistingScreenTimeFirst: Bool,
        cancelAlertsWhenDisabled: Bool,
        includeStartReminder: Bool,
        logPrefix: String
    ) async {
        let tag = runID.uuidString.prefix(8)
        guard activeRunID == runID, !Task.isCancelled else { return }

        if stopExistingScreenTimeFirst {
            // Stand down any previously-scheduled bathroom session monitoring
            // before deciding whether to reschedule it under the new mode -
            // the old schedule may no longer reflect the user's current choice.
            await screenTimeSessionScheduling.stopBathroomSessionMonitoring()
            guard activeRunID == runID, !Task.isCancelled else { return }
        }

        if preferences.focusLockBlockingWillEngage {
            log.debug("[\(tag)] \(logPrefix)starting bathroom session monitoring...")
            await screenTimeSessionScheduling.startBathroomSessionMonitoring(duration: alertDuration)
        }
        guard activeRunID == runID, !Task.isCancelled else { return }

        let messagingMode = resolvedMessagingMode(preferences)

        let alarmKitHandling: Bool
        if preferences.timerAlertsEnabled {
            log.debug("[\(tag)] \(logPrefix)scheduling AlarmKit...")
            let alarmKitID = await alarmKitService.scheduleTimer(
                duration: alertDuration,
                presetName: preset.name,
                messagingMode: messagingMode,
                cooldownMinutes: preferences.focusLockCooldownMinutes
            )
            alarmKitHandling = alarmKitID != nil
            log.debug("[\(tag)] \(logPrefix)AlarmKit done ✓ (id=\(alarmKitID?.uuidString.prefix(8) ?? "nil"), handling=\(alarmKitHandling))")
        } else {
            alarmKitHandling = false
            if cancelAlertsWhenDisabled {
                await alarmKitService.cancelActive()
            } else {
                log.debug("[\(tag)] \(logPrefix)AlarmKit skipped - timer alerts disabled")
            }
        }
        guard activeRunID == runID, !Task.isCancelled else { return }

        if preferences.timerAlertsEnabled {
            log.debug("[\(tag)] \(logPrefix)scheduling notifications...")
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
                    duration: alertDuration,
                    endDate: endDate,
                    sound: preferences.warningSound
                )
            }
            if includeStartReminder && preferences.focusLockMode == .phoneFree {
                await notificationService.scheduleStartReminder(mode: .phoneFree)
            }
            log.debug("[\(tag)] \(logPrefix)notifications scheduled ✓")
        } else if cancelAlertsWhenDisabled {
            await notificationService.cancelAll()
        }
    }

    /// Resolves the mode that should actually drive completion messaging;
    /// falls back to `nil` (today's neutral default copy) when Limited
    /// Scrolling was picked but blocking won't really engage.
    private func resolvedMessagingMode(_ preferences: TimerPreferences) -> FocusLockMode? {
        FocusLockMode.effective(selected: preferences.focusLockMode, blockingWillEngage: preferences.focusLockBlockingWillEngage)
    }

    private func startCountdownTask(
        runID: UUID,
        endDate: Date,
        preset: PresetTimer,
        duration: TimeInterval,
        initialRemaining: TimeInterval,
        beepsEnabled: Bool,
        warningMode: WarningMode = .endOnly,
        hapticsEnabled: Bool,
        player: AlarmPlayer
    ) {
        countdownTask = Task {
            // End-only: single beep at T-30. Recurring: beep at every 30s boundary.
            var nextBeepAt: TimeInterval
            if warningMode == .endOnly {
                nextBeepAt = min(30, initialRemaining)
            } else {
                nextBeepAt = floor(initialRemaining / 30) * 30
                if nextBeepAt >= initialRemaining { nextBeepAt -= 30 }
            }
            log.debug("beep schedule: first beep at \(nextBeepAt)s remaining (duration=\(duration)s, initialRemaining=\(String(format: "%.1f", initialRemaining))s, mode=\(warningMode.rawValue), haptics=\(hapticsEnabled))")

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
    /// explicit start. Expired, retired, or superseded timers (e.g. a queued
    /// WatchConnectivity message delivered long after the fact) are ignored.
    func adopt(
        endDate: Date,
        preset: PresetTimer,
        duration: TimeInterval,
        remoteRunID: UUID? = nil,
        sentAt: Date? = nil
    ) async {
        let remaining = endDate.timeIntervalSince(Date())
        guard remaining > 0 else {
            log.debug("adopt skipped - timer already expired (\(String(format: "%.0f", remaining))s)")
            return
        }
        if let remoteRunID, retiredSyncRunIDs.contains(remoteRunID) {
            log.debug("adopt skipped - runID \(remoteRunID.uuidString.prefix(8)) is already retired")
            return
        }
        if isRunning, let remoteRunID, remoteRunID == syncRunID {
            log.debug("adopt skipped - already running runID \(remoteRunID.uuidString.prefix(8))")
            return
        }
        if isRunning, let sentAt, let currentRunStartedAt, sentAt < currentRunStartedAt {
            log.debug("adopt skipped - message sentAt \(sentAt) predates active run \(currentRunStartedAt)")
            return
        }

        log.debug("adopting timer - endDate=\(endDate), preset=\(preset.name), duration=\(duration)s, remaining=\(String(format: "%.0f", remaining))s")

        countdownTask?.cancel()
        countdownTask = nil
        sideEffectsTask?.cancel()
        await sideEffectsTask?.value
        sideEffectsTask = nil

        if let remoteRunID, retiredSyncRunIDs.contains(remoteRunID) {
            log.debug("adopt skipped after teardown - runID \(remoteRunID.uuidString.prefix(8)) was retired while awaiting")
            return
        }
        if isRunning, let sentAt, let currentRunStartedAt, sentAt < currentRunStartedAt {
            log.debug("adopt skipped after teardown - newer local run superseded it")
            return
        }

        retireSyncRunID(syncRunID ?? activeRunID)
        let runID = UUID()
        let effectiveSyncRunID = remoteRunID ?? runID
        activeRunID = runID
        syncRunID = effectiveSyncRunID
        currentRunStartedAt = sentAt ?? Date()
        isPreparingTimer = true
        currentEndDate = endDate
        currentPreset = preset
        currentDuration = duration

        broadcast(.started(endDate: endDate, preset: preset, duration: duration))
        broadcastSync(.started(runID: effectiveSyncRunID, endDate: endDate, preset: preset, duration: duration, sentAt: Date()))

        // Read user preferences for the services we're about to start.
        let adoptedPreferences = await TimerPreferences.current()
        let adoptedBeepsEnabled = adoptedPreferences.timerWarningEnabled

        if sideEffectsEnabled {
            // Start the Live Activity so the Dynamic Island / Lock Screen show the timer.
            // Awaited eagerly (like `start()`) rather than folded into the
            // tracked side-effects task: LiveActivityService is idempotent:
            // `end()`/`dismiss()` sweep up any orphaned activity even if this
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

        guard activeRunID == runID else { return }
        isPreparingTimer = false
        startCountdownTask(
            runID: runID,
            endDate: endDate,
            preset: preset,
            duration: duration,
            initialRemaining: endDate.timeIntervalSince(Date()),
            beepsEnabled: adoptedBeepsEnabled,
            warningMode: adoptedPreferences.warningMode,
            hapticsEnabled: adoptedPreferences.timerAlertHapticsEnabled,
            player: alarmPlayer
        )
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
        await applyTimerSideEffects(
            runID: runID,
            endDate: endDate,
            preset: preset,
            alertDuration: remaining,
            preferences: preferences,
            stopExistingScreenTimeFirst: false,
            cancelAlertsWhenDisabled: false,
            includeStartReminder: true,
            logPrefix: "adopted: "
        )
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
        // Deliberately does NOT re-fire `scheduleStartReminder` - that's
        // a timer-*start* message, not a timer-end one, and re-sending it
        // mid-session on every settings tweak would be spammy/confusing.
        await applyTimerSideEffects(
            runID: runID,
            endDate: endDate,
            preset: preset,
            alertDuration: remaining,
            preferences: preferences,
            stopExistingScreenTimeFirst: true,
            cancelAlertsWhenDisabled: true,
            includeStartReminder: false,
            logPrefix: "reschedule: "
        )
        log.debug("[\(tag)] reschedule complete ✓")
    }

    /// The user disabled notifications in Settings. Unlike
    /// `rescheduleForFocusLockChange()`, which only acts while a timer is
    /// active (`activeRunID != nil`), this must cancel every alert source
    /// unconditionally - timer running or not - because a pending
    /// post-completion cooldown-complete notification can outlive the run
    /// itself, and `rescheduleForFocusLockChange()` has no reason to reach
    /// it.
    ///
    /// Uses the same cancel-and-await ordering as `stop()`/
    /// `handleExternalAlarmStop()`: `start()`/`adopt()`'s side-effects task
    /// can still be mid-flight (e.g. suspended inside
    /// `AlarmKitService.scheduleTimer(...)`'s call to
    /// `AlarmManager.shared.schedule(...)`) when this runs. `AlarmKitService`
    /// has no generation/token guard of its own (unlike `NotificationService`,
    /// whose `add()` re-checks its scheduling token after the call lands and
    /// undoes a stale write) - so calling it directly, without first waiting
    /// for `sideEffectsTask`, can find nothing scheduled yet and let a
    /// same-moment `scheduleTimer(...)` land afterward, leaving an AlarmKit
    /// alarm armed after the user just turned notifications off. Only
    /// awaiting `sideEffectsTask` first guarantees this cancellation is the
    /// last writer. Safe to call whether or not a timer is running.
    func cancelAlertsForNotificationsDisabled() async {
        let tag = activeRunID?.uuidString.prefix(8) ?? "nil"
        log.debug("cancelAlertsForNotificationsDisabled - runID=\(tag)")
        sideEffectsTask?.cancel()
        await sideEffectsTask?.value
        sideEffectsTask = nil

        guard sideEffectsEnabled else { return }
        await alarmPlayer.stopAlarm()
        await notificationService.cancelAll()
        await alarmKitService.cancelActive()
    }

    /// Stops the active timer only if it matches the Watch's `runID` (or if
    /// `runID` is `nil` from a legacy Watch payload). Always retires a non-nil
    /// `runID` so an out-of-order `.timerStarted` for that same run can never
    /// resurrect it later.
    func stopFromWatch(runID: UUID? = nil) async {
        if let runID {
            retireSyncRunID(runID)
            let activeSyncID = syncRunID ?? activeRunID
            if isRunning, activeSyncID != runID {
                log.debug("stopFromWatch ignored - runID \(runID.uuidString.prefix(8)) does not match active run \(activeSyncID?.uuidString.prefix(8) ?? "nil")")
                return
            }
        }
        guard isRunning else { return }
        await stop()
    }

    func stop() async {
        let tag = activeRunID?.uuidString.prefix(8) ?? "nil"
        log.debug("stop() called - runID=\(tag)")
        let stoppedSyncRunID = syncRunID ?? activeRunID
        retireSyncRunID(stoppedSyncRunID)
        countdownTask?.cancel()
        countdownTask = nil
        activeRunID = nil
        syncRunID = nil
        currentRunStartedAt = nil
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
        await handleCancelled(syncRunID: stoppedSyncRunID)
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
        retireSyncRunID(syncRunID ?? activeRunID)
        countdownTask?.cancel()
        countdownTask = nil
        activeRunID = nil
        syncRunID = nil
        currentRunStartedAt = nil
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
        let completedSyncRunID = syncRunID ?? activeRunID
        retireSyncRunID(completedSyncRunID)
        countdownTask = nil
        activeRunID = nil
        syncRunID = nil
        currentRunStartedAt = nil
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
        if let completedSyncRunID {
            broadcastSyncTerminal(.completed(runID: completedSyncRunID, preset: preset, duration: duration, sentAt: Date()))
        }
    }

    private func handleCancelled(syncRunID: UUID?) async {
        log.debug("handleCancelled")
        countdownTask = nil
        activeRunID = nil
        self.syncRunID = nil
        currentRunStartedAt = nil
        isPreparingTimer = false
        if sideEffectsEnabled {
            await sharedStateService.clearTimer()
            await liveActivityService.end()
            await notificationService.cancelAll()
            await screenTimeSessionScheduling.stopBathroomSessionMonitoring()
        }
        broadcastTerminal(.cancelled)
        if let syncRunID {
            broadcastSyncTerminal(.cancelled(runID: syncRunID, sentAt: Date()))
        }
    }
}
