import Foundation
import Testing
@testable import RHOIDS

/// Records calls so tests can verify `TimerService` drives bathroom-session
/// Device Activity scheduling correctly - the mechanism that makes Limited
/// Scrolling's app-blocking reliable even when the host app is suspended by
/// the time the timer ends. Real `ScreenTimeService` scheduling isn't
/// exercisable in a unit-test environment (no FamilyControls authorization),
/// so this spy stands in for it.
@MainActor
final class ScreenTimeSessionSchedulingSpy: ScreenTimeSessionScheduling {
    private(set) var startCallCount = 0
    private(set) var lastStartedDuration: TimeInterval?
    private(set) var stopCallCount = 0

    func startBathroomSessionMonitoring(duration: TimeInterval) {
        startCallCount += 1
        lastStartedDuration = duration
    }

    func stopBathroomSessionMonitoring() {
        stopCallCount += 1
    }
}

@MainActor
struct TimerServiceScreenTimeSchedulingTests {

    private func makeService(spy: ScreenTimeSessionSchedulingSpy) -> TimerService {
        TimerService(
            notificationService: NotificationService(),
            liveActivityService: LiveActivityService(),
            sharedStateService: SharedStateService(suiteName: "com.test.rhoids.stssched-\(UUID().uuidString)"),
            alarmPlayer: AlarmPlayer(),
            alarmKitService: AlarmKitService(),
            screenTimeSessionScheduling: spy,
            sideEffectsEnabled: true // must be true - this is the path `sideEffectsEnabled: false` tests skip entirely
        )
    }

    private func engagedPrefs() -> TimerService.TimerPreferences {
        TimerService.TimerPreferences(
            notificationsEnabled: false,
            warningEnabled: false,
            warningMode: .endOnly,
            hapticsEnabled: false,
            alarmSound: .systemDefault,
            warningSound: .systemDefault,
            focusLockMode: .limitedScrolling,
            focusLockBlockingWillEngage: true,
            focusLockCooldownMinutes: 5
        )
    }

    private func notEngagedPrefs() -> TimerService.TimerPreferences {
        TimerService.TimerPreferences(
            notificationsEnabled: false,
            warningEnabled: false,
            warningMode: .endOnly,
            hapticsEnabled: false,
            alarmSound: .systemDefault,
            warningSound: .systemDefault,
            focusLockMode: .phoneFree,
            focusLockBlockingWillEngage: false,
            focusLockCooldownMinutes: 5
        )
    }

    @Test("start() schedules bathroom session monitoring when blocking will engage")
    func startSchedulesWhenEngaged() async {
        let spy = ScreenTimeSessionSchedulingSpy()
        let service = makeService(spy: spy)

        await service.start(duration: 120, preset: .recommended, preferences: engagedPrefs())
        try? await Task.sleep(for: .milliseconds(150))

        #expect(spy.startCallCount == 1, "Should schedule exactly once when Limited Scrolling will actually block")
        #expect(spy.lastStartedDuration == 120)

        await service.stop()
    }

    @Test("start() does not schedule bathroom session monitoring when blocking will not engage")
    func startSkipsWhenNotEngaged() async {
        let spy = ScreenTimeSessionSchedulingSpy()
        let service = makeService(spy: spy)

        await service.start(duration: 120, preset: .recommended, preferences: notEngagedPrefs())
        try? await Task.sleep(for: .milliseconds(150))

        #expect(spy.startCallCount == 0, "Phone-Free (and denied/unselected Limited Scrolling) must never schedule blocking")

        await service.stop()
    }

    @Test("stop() cancels any pending bathroom session monitoring")
    func stopCancelsMonitoring() async {
        let spy = ScreenTimeSessionSchedulingSpy()
        let service = makeService(spy: spy)

        await service.start(duration: 120, preset: .recommended, preferences: engagedPrefs())
        try? await Task.sleep(for: .milliseconds(150))
        await service.stop()

        #expect(spy.stopCallCount == 1,
                "An early stop must cancel the pending schedule so apps aren't shielded later at the original end time")
    }

    @Test("stop() cancels bathroom session monitoring even when nothing was engaged")
    func stopIsIdempotentWhenNothingScheduled() async {
        let spy = ScreenTimeSessionSchedulingSpy()
        let service = makeService(spy: spy)

        await service.start(duration: 120, preset: .recommended, preferences: notEngagedPrefs())
        try? await Task.sleep(for: .milliseconds(150))
        await service.stop()

        #expect(spy.stopCallCount == 1, "stop() should call through unconditionally; the spy/real service handles the no-op safely")
    }

    // MARK: - rescheduleForFocusLockChange()

    @Test("rescheduleForFocusLockChange is a no-op when nothing is running")
    func rescheduleNoOpWhenIdle() async {
        let spy = ScreenTimeSessionSchedulingSpy()
        let service = makeService(spy: spy)

        await service.rescheduleForFocusLockChange()

        #expect(spy.startCallCount == 0)
        #expect(spy.stopCallCount == 0)
    }

    @Test("rescheduleForFocusLockChange stands down a previously-engaged schedule when freshly-read preferences no longer engage blocking")
    func rescheduleStopsMonitoringWhenNoLongerEngaged() async {
        let spy = ScreenTimeSessionSchedulingSpy()
        let service = makeService(spy: spy)

        await service.start(duration: 120, preset: .recommended, preferences: engagedPrefs())
        try? await Task.sleep(for: .milliseconds(150))
        #expect(spy.startCallCount == 1)

        // `rescheduleForFocusLockChange()` reads real `TimerPreferences.current()`,
        // not an injected value - and Screen Time is never authorized in a
        // unit-test host, so the effective mode always resolves to "not
        // engaged" here. That's exactly the scenario this test wants: a
        // reschedule must always stand down a stale engaged schedule rather
        // than leave it active, regardless of what re-engages it.
        await service.rescheduleForFocusLockChange()
        try? await Task.sleep(for: .milliseconds(150))

        #expect(spy.stopCallCount >= 1,
                "Reschedule must cancel the previous schedule so a mid-session opt-out isn't silently delayed")
        #expect(spy.startCallCount == 1,
                "Should not re-engage blocking when the freshly-read preferences resolve to not-authorized")

        await service.stop()
    }
}
