import Foundation
import SwiftData
import Testing
@testable import RHOIDS

/// Regression coverage for session logging when a timer's completion is
/// detected long after the timer actually expired.
///
/// A timer left pending across app restarts (started Jun 3, app reopened
/// Jun 10) used to record `endedAt = Date()` at detection time inside
/// `tryRecoverCompletion()`, so History showed a multi-day session for a
/// 3-minute timer. The recovered session must end at
/// `startedAt + plannedDuration` - the moment the timer really finished.
@MainActor
struct TimerViewModelSessionLoggingTests {

    @Test("Recovering a long-expired timer logs a session ending at its planned end, not at detection time")
    func staleRecoveryLogsPlannedEnd() async throws {
        let suiteName = freshSuiteName()
        let sharedState = SharedStateService(suiteName: suiteName)
        // A 3-minute widget-started timer that expired a week before the
        // app was next opened.
        let staleEndDate = Date().addingTimeInterval(-7 * 86_400)
        sharedState.setTimer(endDate: staleEndDate, presetName: "Recommended", duration: 180)

        let context = try makeInMemoryContext()
        let vm = makeViewModel(sharedStateService: sharedState, suiteName: suiteName)
        vm.setModelContext(context)

        vm.startObserving()
        await waitUntil { vm.outcome != nil }
        vm.stopObserving()

        let sessions = try context.fetch(FetchDescriptor<TimerSession>())
        #expect(sessions.count == 1, "Recovery should log exactly one session")
        let session = try #require(sessions.first)
        #expect(session.wasInterrupted == false)
        #expect(abs(session.startedAt.timeIntervalSince(staleEndDate.addingTimeInterval(-180))) < 1,
                "Session should be dated when the timer actually ran")
        let endedAt = try #require(session.endedAt)
        #expect(abs(endedAt.timeIntervalSince(staleEndDate)) < 1,
                "Session must end when the timer expired, not when the app noticed")
        #expect(abs(session.actualDuration - 180) < 1,
                "A 3-minute timer must never record a multi-day duration")
    }

    @Test("Stopping a timer early still logs the real elapsed time at the moment of the stop")
    func earlyStopLogsActualElapsed() async throws {
        let suiteName = freshSuiteName()
        let sharedState = SharedStateService(suiteName: suiteName)
        let timerService = makeTimerService(suiteName: suiteName)
        let context = try makeInMemoryContext()
        let vm = makeViewModel(timerService: timerService,
                               sharedStateService: sharedState, suiteName: suiteName)
        vm.setModelContext(context)

        vm.startObserving()
        // Let observeTimer register its event-stream listener before starting.
        try? await Task.sleep(for: .milliseconds(100))
        await timerService.start(duration: 180, preset: .recommended, preferences: quietPrefs())
        await waitUntil { vm.plannedDuration == 180 }

        vm.stopTimer()
        await waitUntil { vm.outcome != nil }
        vm.stopObserving()

        let sessions = try context.fetch(FetchDescriptor<TimerSession>())
        let session = try #require(sessions.first, "Early stop should log a session")
        #expect(session.wasInterrupted == true)
        #expect(session.actualDuration < 10,
                "An immediate stop should record only the few seconds that elapsed")
        let endedAt = try #require(session.endedAt)
        #expect(abs(endedAt.timeIntervalSinceNow) < 10,
                "An early stop ends now - the planned-end clamp must not rewrite it")
    }

    // MARK: - Helpers

    /// Polls `condition` on the main actor until it holds or the timeout lapses.
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func freshSuiteName() -> String {
        "com.test.rhoids.tvmlog-\(UUID().uuidString)"
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TimerSession.self, configurations: config)
        return ModelContext(container)
    }

    private func makeTimerService(suiteName: String) -> TimerService {
        TimerService(
            notificationService: NotificationService(),
            liveActivityService: LiveActivityService(),
            sharedStateService: SharedStateService(suiteName: suiteName),
            alarmPlayer: AlarmPlayer(),
            alarmKitService: AlarmKitService(),
            screenTimeSessionScheduling: NoOpScreenTimeSessionScheduling(),
            sideEffectsEnabled: false
        )
    }

    private func makeViewModel(timerService: TimerService? = nil,
                               sharedStateService: SharedStateService,
                               suiteName: String) -> TimerViewModel {
        // Bind Focus Lock to the isolated test suite so recovery never
        // applies real Screen Time shields during tests.
        let preferences = FocusLockPreferences(suiteName: suiteName)
        preferences.isEnabled = false
        return TimerViewModel(
            timerService: timerService ?? makeTimerService(suiteName: suiteName),
            alarmPlayer: AlarmPlayer(),
            sharedStateService: sharedStateService,
            liveActivityService: LiveActivityService(),
            alarmKitService: AlarmKitService(),
            screenTimeService: ScreenTimeService(),
            focusLockPreferences: preferences
        )
    }

    private func quietPrefs() -> TimerService.TimerPreferences {
        TimerService.TimerPreferences(
            notificationsEnabled: false,
            warningEnabled: false,
            warningMode: .endOnly,
            hapticsEnabled: false,
            alarmSound: .systemDefault,
            warningSound: .systemDefault
        )
    }
}
