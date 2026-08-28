import Foundation
import Testing
@testable import RHOIDS

@MainActor
struct TimerServiceAdoptionTests {

    // MARK: - adoptSharedStateIfNeeded

    @Test("Adopts a widget-started timer from shared state")
    func adoptsWidgetTimer() async {
        let suiteName = "com.test.rhoids.adopt-\(UUID().uuidString)"
        let sharedState = SharedStateService(suiteName: suiteName)
        let service = makeService(suiteName: suiteName)

        let endDate = Date().addingTimeInterval(120)
        sharedState.setTimer(endDate: endDate, presetName: "Recommended", duration: 180)

        await service.adoptSharedStateIfNeeded()

        let state = await service.timerState()
        #expect(state.isRunning == true, "Should adopt the widget-started timer")
        #expect(state.duration == 180)

        await service.stop()
    }

    @Test("Does not adopt when no timer is in shared state")
    func doesNotAdoptWhenEmpty() async {
        let suiteName = "com.test.rhoids.adopt-\(UUID().uuidString)"
        let service = makeService(suiteName: suiteName)

        await service.adoptSharedStateIfNeeded()

        let state = await service.timerState()
        #expect(state.isRunning == false, "Nothing to adopt")
    }

    @Test("Does not adopt when timer already running locally")
    func doesNotAdoptWhenAlreadyRunning() async {
        let suiteName = "com.test.rhoids.adopt-\(UUID().uuidString)"
        let sharedState = SharedStateService(suiteName: suiteName)
        let service = makeService(suiteName: suiteName)

        await service.start(duration: 60, preset: .recommended, preferences: quietPrefs())

        let endDate = Date().addingTimeInterval(300)
        sharedState.setTimer(endDate: endDate, presetName: "Max", duration: 300)

        await service.adoptSharedStateIfNeeded()

        let state = await service.timerState()
        #expect(state.duration == 60,
                "Should keep local timer, not adopt the shared one")

        await service.stop()
    }

    @Test("Does not adopt when shared timer has already expired")
    func doesNotAdoptExpiredTimer() async {
        let suiteName = "com.test.rhoids.adopt-\(UUID().uuidString)"
        let sharedState = SharedStateService(suiteName: suiteName)
        let service = makeService(suiteName: suiteName)

        let pastDate = Date().addingTimeInterval(-60)
        sharedState.setTimer(endDate: pastDate, presetName: "Recommended", duration: 180)

        await service.adoptSharedStateIfNeeded()

        let state = await service.timerState()
        #expect(state.isRunning == false,
                "Should not adopt a timer that already ended")
    }

    // MARK: - SharedStateService round-trip

    @Test("setTimer then getTimerState returns correct values")
    func sharedStateRoundTrip() async throws {
        let suiteName = "com.test.rhoids.ss-\(UUID().uuidString)"
        let service = SharedStateService(suiteName: suiteName)
        let endDate = Date().addingTimeInterval(120)

        service.setTimer(endDate: endDate, presetName: "Max", duration: 300)
        let state = service.getTimerState()

        #expect(state.isRunning == true)
        #expect(state.presetName == "Max")
        #expect(state.duration == 300)
        let storedEndDate = try #require(state.endDate, "endDate should be set after setTimer")
        #expect(abs(storedEndDate.timeIntervalSince(endDate)) < 1)
    }

    @Test("clearTimer resets all fields")
    func clearTimerResetsAll() async {
        let suiteName = "com.test.rhoids.ss-\(UUID().uuidString)"
        let service = SharedStateService(suiteName: suiteName)

        service.setTimer(endDate: Date().addingTimeInterval(60), presetName: "Test", duration: 60)
        service.clearTimer()

        let state = service.getTimerState()
        #expect(state.isRunning == false)
        #expect(state.endDate == nil)
        #expect(state.presetName == nil)
        #expect(state.duration == 0)
    }

    @Test("getTimerState on fresh suite returns empty state")
    func freshSuiteReturnsEmpty() {
        let suiteName = "com.test.rhoids.ss-\(UUID().uuidString)"
        let service = SharedStateService(suiteName: suiteName)
        let state = service.getTimerState()
        #expect(state.isRunning == false)
        #expect(state.endDate == nil)
        #expect(state.presetName == nil)
        #expect(state.duration == 0)
    }

    // MARK: - Helpers

    private func makeService(suiteName: String) -> TimerService {
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
