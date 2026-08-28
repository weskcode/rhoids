import Foundation
import WatchKit
import WidgetKit
import os.log

/// Actor-isolated timer service for the Apple Watch.
///
/// Mirrors the iPhone `TimerService` but lighter:
/// - No AlarmKit (unavailable on watchOS)
/// - No Live Activity
/// - Uses `WKExtendedRuntimeSession` for background countdown reliability
/// - Fires haptics via `WatchHaptics` on completion and warning intervals

private let log = Logger(subsystem: "com.wesley.RHOIDS.watch", category: "TimerService")

actor WatchTimerService {
    private static let complicationKind = "RHOIDSWatchComplication"

    private var countdownTask: Task<Void, Never>?
    private var activeRunID: UUID?
    private var extendedSession: WKExtendedRuntimeSession?
    private var listeners: [UUID: AsyncStream<WatchTimerEvent>.Continuation] = [:]

    private(set) var currentEndDate: Date?
    private(set) var currentPreset: PresetTimer?
    private(set) var currentDuration: TimeInterval = 0
    var isRunning: Bool { countdownTask != nil }

    private let connectivityService: WatchConnectivityService

    init(connectivityService: WatchConnectivityService) {
        self.connectivityService = connectivityService
        log.debug("initialized")
    }

    // MARK: - Event Stream

    func eventStream() -> AsyncStream<WatchTimerEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: WatchTimerEvent.self)
        listeners[id] = continuation
        continuation.onTermination = { [id] _ in
            Task { await self.removeListener(id: id) }
        }
        return stream
    }

    private func removeListener(id: UUID) {
        listeners.removeValue(forKey: id)
    }

    private func broadcast(_ event: WatchTimerEvent) {
        for continuation in listeners.values {
            continuation.yield(event)
        }
    }

    // MARK: - Start

    func start(duration: TimeInterval, preset: PresetTimer) async {
        log.debug("start - duration=\(duration)s, preset=\(preset.name)")
        countdownTask?.cancel()
        countdownTask = nil
        let runID = UUID()
        activeRunID = runID

        let endDate = Date().addingTimeInterval(duration)
        currentEndDate = endDate
        currentPreset = preset
        currentDuration = duration

        await persistComplicationState(endDate: endDate, presetName: preset.name, duration: duration)
        guard activeRunID == runID else { return }
        broadcast(.started(endDate: endDate, preset: preset, duration: duration))

        // Notify iPhone
        await MainActor.run {
            connectivityService.send(.timerStarted(
                endDate: endDate,
                presetName: preset.name,
                duration: duration
            ))
        }
        guard activeRunID == runID else { return }

        // Start extended runtime session for background reliability
        startExtendedSession(runID: runID)

        // Haptic feedback
        WatchHaptics.timerStarted()

        runCountdown(runID: runID, endDate: endDate, remainingAtStart: duration)
    }

    // MARK: - Adopt from iPhone

    /// Adopt a timer that was started on the iPhone.
    func adopt(endDate: Date, presetName: String, duration: TimeInterval) async {
        guard endDate > Date() else { return }

        // The iPhone echoes back timers the Watch itself started (Watch start →
        // iPhone adopts → iPhone broadcasts .started → message to Watch). If we
        // are already counting down to the same endDate, don't restart the
        // countdown, haptics, or extended runtime session.
        if countdownTask != nil, let current = currentEndDate,
           abs(current.timeIntervalSince(endDate)) < 1 {
            log.debug("adopt skipped - already tracking this timer")
            return
        }

        // Preserve the carried preset name if it isn't one of the built-ins
        // (e.g. a "Snooze" timer started from the iPhone notification action).
        let preset = PresetTimer.all.first { $0.name == presetName }
            ?? PresetTimer(
                id: UUID(),
                name: presetName,
                duration: duration,
                subtitle: "",
                systemImage: "timer",
                isRecommended: false
            )

        log.debug("adopting iPhone timer - endDate=\(endDate), preset=\(preset.name)")

        countdownTask?.cancel()
        countdownTask = nil
        let runID = UUID()
        activeRunID = runID
        currentEndDate = endDate
        currentPreset = preset
        currentDuration = duration

        await persistComplicationState(endDate: endDate, presetName: preset.name, duration: duration)
        guard activeRunID == runID else { return }
        broadcast(.started(endDate: endDate, preset: preset, duration: duration))
        startExtendedSession(runID: runID)

        // Seed the warning schedule with the time *remaining* at adoption so the
        // beep cadence lines up with the iPhone and no reminders are skipped.
        runCountdown(runID: runID, endDate: endDate, remainingAtStart: endDate.timeIntervalSinceNow)
    }

    // MARK: - Countdown

    /// The shared countdown loop used by both `start` and `adopt`.
    ///
    /// Broadcasts a `.tick` every second, fires warning haptics on the schedule
    /// the user selected, and reports natural completion when the timer runs out.
    private func runCountdown(runID: UUID, endDate: Date, remainingAtStart: TimeInterval) {
        let warningEnabled = UserPreferences.timerWarningEnabled
        let warningMode = UserPreferences.warningMode

        countdownTask = Task {
            var schedule = WatchWarningSchedule(remainingAtStart: remainingAtStart, mode: warningMode)
            var naturalCompletion = false

            while !Task.isCancelled {
                let remaining = endDate.timeIntervalSince(Date())
                if remaining <= 0 {
                    naturalCompletion = true
                    break
                }
                broadcast(.tick(remaining: remaining))

                if warningEnabled, schedule.shouldBeep(remaining: remaining) {
                    WatchHaptics.warningTick()
                }

                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
            }

            if naturalCompletion {
                await handleCompletion(runID: runID)
            }
        }
    }

    // MARK: - Stop

    func stop() async {
        log.debug("stop()")
        countdownTask?.cancel()
        countdownTask = nil
        activeRunID = nil
        currentEndDate = nil
        currentPreset = nil
        currentDuration = 0
        endExtendedSession()
        await clearComplicationState()

        WatchHaptics.timerCancelled()
        broadcast(.cancelled)

        await MainActor.run {
            connectivityService.send(.timerCancelled)
        }
    }

    /// Clear a timer cancelled by the iPhone without echoing another
    /// cancellation message back over WatchConnectivity.
    func cancelFromPhone() async {
        log.debug("phone cancelled timer")
        let wasRunning = countdownTask != nil || currentEndDate != nil
        resetRunningState()
        await clearComplicationState()
        // If nothing was running locally (e.g. the iPhone echoing back a stop
        // the Watch itself initiated), skip the haptic and event so the user
        // isn't buzzed twice for one cancellation.
        guard wasRunning else { return }
        WatchHaptics.timerCancelled()
        broadcast(.cancelled)
    }

    /// Complete a timer reported by the iPhone without turning the event into a
    /// local cancellation. This keeps phone and Watch state convergent.
    func completeFromPhone(presetName: String, duration: TimeInterval) async {
        let preset = PresetTimer.all.first { $0.name == presetName } ?? currentPreset
        log.debug("phone completed timer - preset=\(preset?.name ?? "nil")")
        let wasRunning = countdownTask != nil || currentEndDate != nil
        resetRunningState()
        await clearComplicationState()
        // The Watch's own countdown usually completes this timer first; the
        // iPhone's completion message then arrives moments later. Skip the
        // duplicate haptic + event in that case.
        guard wasRunning else { return }
        if UserPreferences.timerAlertHapticsEnabled {
            WatchHaptics.timerCompleted()
        }
        broadcast(.completed(preset: preset, duration: duration))
    }

    // MARK: - Completion

    private func handleCompletion(runID: UUID) async {
        guard activeRunID == runID else {
            log.debug("ignored completion from a replaced timer run")
            return
        }
        let preset = currentPreset
        let duration = currentDuration

        log.debug("timer completed - preset=\(preset?.name ?? "nil")")
        currentEndDate = nil
        currentPreset = nil
        currentDuration = 0
        countdownTask = nil
        activeRunID = nil
        endExtendedSession()
        await clearComplicationState()

        if UserPreferences.timerAlertHapticsEnabled {
            WatchHaptics.timerCompleted()
        }
        broadcast(.completed(preset: preset, duration: duration))

        await MainActor.run {
            connectivityService.send(.timerCompleted(
                presetName: preset?.name ?? "Unknown",
                duration: duration
            ))
        }
    }

    // MARK: - Extended Runtime Session

    private nonisolated func startExtendedSession(runID: UUID) {
        Task { @MainActor in
            let session = WKExtendedRuntimeSession()
            session.start()
            await self.setExtendedSession(session, runID: runID)
        }
    }

    private func setExtendedSession(_ session: WKExtendedRuntimeSession, runID: UUID) {
        guard activeRunID == runID else {
            session.invalidate()
            log.debug("discarded extended runtime session for an inactive timer")
            return
        }
        // Invalidate any session left over from a replaced timer so it
        // doesn't keep the app awake past its run.
        extendedSession?.invalidate()
        self.extendedSession = session
        log.debug("extended runtime session started")
    }

    private nonisolated func endExtendedSession() {
        Task { @MainActor in
            await self.invalidateExtendedSession()
        }
    }

    private func invalidateExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
        log.debug("extended runtime session ended")
    }

    private func resetRunningState() {
        countdownTask?.cancel()
        countdownTask = nil
        activeRunID = nil
        currentEndDate = nil
        currentPreset = nil
        currentDuration = 0
        endExtendedSession()
    }

    private func persistComplicationState(endDate: Date, presetName: String, duration: TimeInterval) async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: SharedStateKeys.suiteName)
            defaults?.set(endDate, forKey: SharedStateKeys.timerEndDate)
            defaults?.set(true, forKey: SharedStateKeys.timerIsRunning)
            defaults?.set(presetName, forKey: SharedStateKeys.timerPresetName)
            defaults?.set(duration, forKey: SharedStateKeys.timerDuration)
            WidgetCenter.shared.reloadTimelines(ofKind: Self.complicationKind)
        }
    }

    private func clearComplicationState() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: SharedStateKeys.suiteName)
            defaults?.removeObject(forKey: SharedStateKeys.timerEndDate)
            defaults?.set(false, forKey: SharedStateKeys.timerIsRunning)
            defaults?.removeObject(forKey: SharedStateKeys.timerPresetName)
            defaults?.removeObject(forKey: SharedStateKeys.timerDuration)
            WidgetCenter.shared.reloadTimelines(ofKind: Self.complicationKind)
        }
    }
}

// MARK: - Watch Timer Events

enum WatchTimerEvent: Sendable {
    case started(endDate: Date, preset: PresetTimer, duration: TimeInterval)
    case tick(remaining: TimeInterval)
    case completed(preset: PresetTimer?, duration: TimeInterval)
    case cancelled
}
