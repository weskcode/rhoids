import Foundation
import Testing
@testable import RHOIDS

/// Regression coverage for Focus Lock shielding on timer completion.
///
/// `TimerViewModel` must apply Focus Lock shields when a timer completes - /// on BOTH completion paths - but only while Focus Lock is enabled:
/// 1. The live `.completed` event in `observeTimer()`.
/// 2. `tryRecoverCompletion()`, the widget-started-timer recovery path that
///    runs when the app is opened after a timer already finished. A prior bug
///    omitted `applyShields()` from this path; these tests lock that down.
///
/// Each test injects a `FocusLockPreferences` bound to a fresh, per-test
/// `UserDefaults` suite rather than the shared App Group, so the
/// `focusLockEnabled` flag can no longer leak across concurrently running
/// tests or suites - that was the original cross-suite data race.
///
/// Still `.serialized`: the live `.completed` tests depend on a wall-clock
/// handshake (sleep to let `observeTimer` register its listener, then fire a
/// sub-second timer). Running them concurrently makes that timing fragile under
/// CPU contention, so we keep them one-at-a-time within the suite.
@MainActor
@Suite(.serialized)
struct TimerViewModelShieldingTests {

    // MARK: - Spy

    /// Records `applyShields()` invocations so tests can assert the view model
    /// drives shielding without depending on real FamilyControls tokens.
    private final class ScreenTimeShieldingSpy: ScreenTimeShielding {
        private(set) var applyShieldsCallCount = 0
        func applyShields() { applyShieldsCallCount += 1 }
    }

    // MARK: - Live `.completed` path

    @Test("observeTimer .completed applies shields when Focus Lock is enabled")
    func liveCompletionAppliesShieldsWhenEnabled() async {
        let spy = ScreenTimeShieldingSpy()
        let suiteName = freshSuiteName()
        let timerService = makeTimerService(suiteName: suiteName)
        let vm = makeViewModel(timerService: timerService, screenTimeService: spy,
                               suiteName: suiteName, focusLockEnabled: true)

        vm.startObserving()
        // Let observeTimer reach the event-stream loop and register its
        // listener before the timer fires its terminal `.completed` event.
        try? await Task.sleep(for: .milliseconds(100))
        await timerService.start(duration: 0.5, preset: .recommended, preferences: quietPrefs())

        await waitUntil { vm.outcome != nil }
        vm.stopObserving()

        #expect(vm.outcome != nil, "Timer should have completed")
        #expect(spy.applyShieldsCallCount == 1,
                "Live completion must apply shields exactly once when Focus Lock is enabled")
    }

    @Test("observeTimer .completed does not apply shields when Focus Lock is disabled")
    func liveCompletionDoesNotApplyShieldsWhenDisabled() async {
        let spy = ScreenTimeShieldingSpy()
        let suiteName = freshSuiteName()
        let timerService = makeTimerService(suiteName: suiteName)
        let vm = makeViewModel(timerService: timerService, screenTimeService: spy,
                               suiteName: suiteName, focusLockEnabled: false)

        vm.startObserving()
        try? await Task.sleep(for: .milliseconds(100))
        await timerService.start(duration: 0.5, preset: .recommended, preferences: quietPrefs())

        await waitUntil { vm.outcome != nil }
        vm.stopObserving()

        #expect(vm.outcome != nil, "Timer should have completed")
        #expect(spy.applyShieldsCallCount == 0,
                "Live completion must not apply shields when Focus Lock is disabled")
    }

    // MARK: - Recovery path (`tryRecoverCompletion`)

    @Test("tryRecoverCompletion applies shields when Focus Lock is enabled")
    func recoveryAppliesShieldsWhenEnabled() async {
        let spy = ScreenTimeShieldingSpy()
        let suiteName = freshSuiteName()
        let sharedState = SharedStateService(suiteName: suiteName)
        // A widget-started timer that already expired while the app was closed.
        sharedState.setTimer(endDate: Date().addingTimeInterval(-5), presetName: "Recommended", duration: 180)

        let timerService = makeTimerService(suiteName: suiteName)
        let vm = makeViewModel(timerService: timerService, screenTimeService: spy,
                               sharedStateService: sharedState, suiteName: suiteName, focusLockEnabled: true)

        vm.startObserving()
        await waitUntil { vm.outcome != nil }
        vm.stopObserving()

        #expect(vm.outcome != nil, "Recovery should surface a completion outcome")
        #expect(spy.applyShieldsCallCount == 1,
                "Recovery path must apply shields exactly once when Focus Lock is enabled")
    }

    @Test("tryRecoverCompletion does not apply shields when Focus Lock is disabled")
    func recoveryDoesNotApplyShieldsWhenDisabled() async {
        let spy = ScreenTimeShieldingSpy()
        let suiteName = freshSuiteName()
        let sharedState = SharedStateService(suiteName: suiteName)
        sharedState.setTimer(endDate: Date().addingTimeInterval(-5), presetName: "Recommended", duration: 180)

        let timerService = makeTimerService(suiteName: suiteName)
        let vm = makeViewModel(timerService: timerService, screenTimeService: spy,
                               sharedStateService: sharedState, suiteName: suiteName, focusLockEnabled: false)

        vm.startObserving()
        await waitUntil { vm.outcome != nil }
        vm.stopObserving()

        #expect(vm.outcome != nil, "Recovery should still surface a completion outcome")
        #expect(spy.applyShieldsCallCount == 0,
                "Recovery path must not apply shields when Focus Lock is disabled")
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
        "com.test.rhoids.tvmshield-\(UUID().uuidString)"
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

    private func makeViewModel(timerService: TimerService,
                               screenTimeService: any ScreenTimeShielding,
                               sharedStateService: SharedStateService? = nil,
                               suiteName: String,
                               focusLockEnabled: Bool) -> TimerViewModel {
        // Bind Focus Lock state to the same isolated suite the rest of the test
        // uses, so the enabled flag never touches the shared App Group.
        let preferences = FocusLockPreferences(suiteName: suiteName)
        preferences.isEnabled = focusLockEnabled
        return TimerViewModel(
            timerService: timerService,
            alarmPlayer: AlarmPlayer(),
            sharedStateService: sharedStateService ?? SharedStateService(suiteName: suiteName),
            liveActivityService: LiveActivityService(),
            alarmKitService: AlarmKitService(),
            screenTimeService: screenTimeService,
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
