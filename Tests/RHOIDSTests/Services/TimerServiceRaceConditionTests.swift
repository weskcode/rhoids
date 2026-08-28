import Foundation
import Testing
@testable import RHOIDS

/// No-op fake for `TimerService`'s Screen Time dependency. Real
/// `ScreenTimeService` requires FamilyControls authorization state that
/// isn't available in a unit-test environment; these race/timing tests only
/// care about AlarmKit/notification/state scheduling, not shielding.
@MainActor
final class NoOpScreenTimeSessionScheduling: ScreenTimeSessionScheduling {
    func startBathroomSessionMonitoring(duration: TimeInterval) {}
    func stopBathroomSessionMonitoring() {}
}

// Time-limited: several tests await event-stream completion; if a terminal
// event regresses, the await would hang the whole run instead of failing.
@Suite(.timeLimit(.minutes(1)))
@MainActor
struct TimerServiceRaceConditionTests {

    // MARK: - Rapid start/stop cycling

    @Test("Rapid start-stop-start leaves timer in a valid running state")
    func rapidStartStopStart() async {
        let service = makeService()

        await service.start(duration: 120, preset: .recommended, preferences: quietPrefs())
        await service.stop()
        await service.start(duration: 180, preset: .maxAllowed, preferences: quietPrefs())

        let state = await service.timerState()
        #expect(state.isRunning == true, "Timer should be running after final start")
        #expect(state.preset == .maxAllowed, "Should reflect the latest preset")
        #expect(state.duration == 180, "Should reflect the latest duration")

        await service.stop()
    }

    @Test("Calling stop twice does not crash or corrupt state")
    func doubleStopIsIdempotent() async {
        let service = makeService()

        await service.start(duration: 60, preset: .recommended, preferences: quietPrefs())
        await service.stop()
        await service.stop()

        let state = await service.timerState()
        #expect(state.isRunning == false)
        #expect(state.endDate == nil)
        #expect(state.duration == 0)
    }

    @Test("Starting a new timer while one is running replaces it cleanly")
    func startWhileRunningReplaces() async {
        let service = makeService()

        await service.start(duration: 300, preset: .maxAllowed, preferences: quietPrefs())
        let firstState = await service.timerState()
        #expect(firstState.isRunning == true)

        await service.start(duration: 60, preset: .recommended, preferences: quietPrefs())
        let secondState = await service.timerState()
        #expect(secondState.isRunning == true)
        #expect(secondState.preset == .recommended, "Second start should fully replace the first")
        #expect(secondState.duration == 60)

        await service.stop()
    }

    @Test("Stop on a never-started timer is safe")
    func stopWithoutStartIsSafe() async {
        let service = makeService()

        await service.stop()

        let state = await service.timerState()
        #expect(state.isRunning == false)
        #expect(state.endDate == nil)
    }

    // MARK: - Event stream lifecycle

    @Test("Event stream created before start receives the started event")
    func streamReceivesStartedEvent() async throws {
        let service = makeService()
        let stream = await service.eventStream()

        let eventTask = Task {
            var iterator = stream.makeAsyncIterator()
            return await iterator.next()
        }

        await service.start(duration: 60, preset: .recommended, preferences: quietPrefs())

        let event = try #require(await eventTask.value)
        guard case .started = event else {
            Issue.record("Expected .started, got \(event)")
            return
        }
        await service.stop()
    }

    @Test("Multiple listeners all receive the same events")
    func multipleListenersReceiveSameEvents() async throws {
        let service = makeService()
        let stream1 = await service.eventStream()
        let stream2 = await service.eventStream()
        let stream3 = await service.eventStream()

        let task1 = Task { var it = stream1.makeAsyncIterator(); return await it.next() }
        let task2 = Task { var it = stream2.makeAsyncIterator(); return await it.next() }
        let task3 = Task { var it = stream3.makeAsyncIterator(); return await it.next() }

        await service.start(duration: 60, preset: .recommended, preferences: quietPrefs())

        let events = await [task1.value, task2.value, task3.value]
        for event in events {
            guard case .started = event else {
                Issue.record("All listeners should receive .started")
                return
            }
        }
        await service.stop()
    }

    @Test("Stop broadcasts cancelled as a terminal event and finishes streams")
    func stopBroadcastsCancelledTerminal() async throws {
        let service = makeService()
        let stream = await service.eventStream()

        await service.start(duration: 120, preset: .recommended, preferences: quietPrefs())

        var events: [TimerEvent] = []
        let collectTask = Task {
            var collected: [TimerEvent] = []
            for await event in stream {
                collected.append(event)
            }
            return collected
        }

        try? await Task.sleep(for: .milliseconds(50))
        await service.stop()

        events = await collectTask.value
        let hasStarted = events.contains { if case .started = $0 { return true }; return false }
        let hasCancelled = events.contains { if case .cancelled = $0 { return true }; return false }

        #expect(hasStarted, "Stream should contain .started")
        #expect(hasCancelled, "Stream should contain .cancelled after stop")
    }

    // MARK: - Zero and minimum duration edge cases

    @Test("Timer with zero duration completes almost immediately without crash")
    func zeroDurationDoesNotCrash() async {
        let service = makeService()
        let stream = await service.eventStream()

        await service.start(duration: 0, preset: .recommended, preferences: quietPrefs())

        let collectTask = Task {
            var events: [TimerEvent] = []
            for await event in stream { events.append(event) }
            return events
        }

        try? await Task.sleep(for: .seconds(2))
        let events = await collectTask.value
        let hasCompleted = events.contains { if case .completed = $0 { return true }; return false }
        #expect(hasCompleted, "Zero-duration timer should fire .completed quickly")
    }

    @Test("Timer with 1-second duration completes within 3 seconds")
    func oneSecondDuration() async throws {
        let service = makeService()
        let stream = await service.eventStream()

        await service.start(duration: 1, preset: .recommended, preferences: quietPrefs())

        let startTime = Date()
        let collectTask = Task {
            var events: [TimerEvent] = []
            for await event in stream { events.append(event) }
            return events
        }

        let events = await collectTask.value
        let elapsed = Date().timeIntervalSince(startTime)

        let hasCompleted = events.contains { if case .completed = $0 { return true }; return false }
        #expect(hasCompleted, "1s timer should complete")
        #expect(elapsed < 3, "Should complete within 3 seconds, took \(elapsed)s")
    }

    // MARK: - Timer preferences edge cases

    @Test("Timer works with all preferences disabled")
    func allPreferencesDisabled() async {
        let service = makeService()

        let prefs = TimerService.TimerPreferences(
            notificationsEnabled: false,
            warningEnabled: false,
            warningMode: .endOnly,
            hapticsEnabled: false,
            alarmSound: .systemDefault,
            warningSound: .systemDefault
        )

        await service.start(duration: 60, preset: .recommended, preferences: prefs)
        let state = await service.timerState()
        #expect(state.isRunning == true, "Timer should run even with all extras disabled")
        await service.stop()
    }

    @Test("Timer works with recurring warning mode on very short duration")
    func recurringModeShortDuration() async {
        let service = makeService()

        let prefs = TimerService.TimerPreferences(
            notificationsEnabled: false,
            warningEnabled: true,
            warningMode: .recurring,
            hapticsEnabled: false,
            alarmSound: .systemDefault,
            warningSound: .systemDefault
        )

        await service.start(duration: 10, preset: .recommended, preferences: prefs)
        let state = await service.timerState()
        #expect(state.isRunning == true)
        await service.stop()
    }

    // MARK: - Helpers

    private func makeService() -> TimerService {
        TimerService(
            notificationService: NotificationService(),
            liveActivityService: LiveActivityService(),
            sharedStateService: SharedStateService(suiteName: "com.test.rhoids.race-\(UUID().uuidString)"),
            alarmPlayer: AlarmPlayer(),
            alarmKitService: AlarmKitService(),
            screenTimeSessionScheduling: NoOpScreenTimeSessionScheduling(),
            sideEffectsEnabled: false
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
