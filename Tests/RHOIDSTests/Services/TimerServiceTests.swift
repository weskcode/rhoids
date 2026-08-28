import Foundation
import Testing
@testable import RHOIDS

@MainActor
struct TimerServiceTests {
    @Test("start broadcasts started before optional side effects")
    func startBroadcastsStartedEvent() async throws {
        let service = makeService()
        let stream = await service.eventStream()
        let eventTask = Task {
            var iterator = stream.makeAsyncIterator()
            return await iterator.next()
        }

        await service.start(
            duration: 120,
            preset: .recommended,
            preferences: TimerService.TimerPreferences(
                notificationsEnabled: false,
                warningEnabled: false,
                hapticsEnabled: false
            )
        )

        let event = try #require(await eventTask.value)
        guard case .started(let endDate, let preset, let duration) = event else {
            Issue.record("Expected .started event")
            return
        }

        #expect(endDate.timeIntervalSinceNow > 110)
        #expect(preset == .recommended)
        #expect(duration == 120)

        let state = await service.timerState()
        #expect(state.isRunning == true)
        #expect(state.preset == .recommended)
        #expect(state.duration == 120)

        await service.stop()
    }

    @Test("stop clears timer state")
    func stopClearsTimerState() async {
        let service = makeService()

        await service.start(
            duration: 120,
            preset: .recommended,
            preferences: TimerService.TimerPreferences(
                notificationsEnabled: false,
                warningEnabled: false,
                hapticsEnabled: false
            )
        )
        await service.stop()

        let state = await service.timerState()
        #expect(state.isRunning == false)
        #expect(state.endDate == nil)
        #expect(state.preset == nil)
        #expect(state.duration == 0)
    }

    // MARK: - External alarm stop (Dynamic Island Stop button)

    @Test("handleExternalAlarmStop clears timer state")
    func externalStopClearsState() async {
        let service = makeService()

        await service.start(duration: 120, preset: .recommended, preferences: quietPreferences())
        await service.handleExternalAlarmStop()

        let state = await service.timerState()
        #expect(state.isRunning == false)
        #expect(state.endDate == nil)
        #expect(state.preset == nil)
        #expect(state.duration == 0)
    }

    @Test("handleExternalAlarmStop does not broadcast a cancelled event")
    func externalStopIsSilent() async {
        let service = makeService()
        let collector = EventCollector()
        let stream = await service.eventStream()
        let consumer = Task {
            for await event in stream { await collector.add(event) }
        }

        await service.start(duration: 120, preset: .recommended, preferences: quietPreferences())
        await service.handleExternalAlarmStop()
        // Let any (incorrect) terminal event propagate before asserting.
        try? await Task.sleep(for: .milliseconds(100))
        consumer.cancel()

        let events = await collector.events
        #expect(events.contains { if case .started = $0 { true } else { false } },
                "The start should still have been broadcast")
        #expect(events.contains { if case .cancelled = $0 { true } else { false } } == false,
                "A timer that reached its end must not be reported as stopped early")
    }

    // MARK: - Helpers

    private func quietPreferences() -> TimerService.TimerPreferences {
        TimerService.TimerPreferences(
            notificationsEnabled: false,
            warningEnabled: false,
            hapticsEnabled: false
        )
    }

    private func makeService() -> TimerService {
        TimerService(
            notificationService: NotificationService(),
            liveActivityService: LiveActivityService(),
            sharedStateService: SharedStateService(suiteName: "com.test.rhoids.timer-\(UUID().uuidString)"),
            alarmPlayer: AlarmPlayer(),
            alarmKitService: AlarmKitService(),
            screenTimeSessionScheduling: NoOpScreenTimeSessionScheduling(),
            sideEffectsEnabled: false
        )
    }
}

/// Collects `TimerEvent`s from a service's event stream so a test can assert
/// on the exact set of events broadcast.
private actor EventCollector {
    private(set) var events: [TimerEvent] = []
    func add(_ event: TimerEvent) { events.append(event) }
}
