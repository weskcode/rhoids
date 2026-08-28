import Foundation
import Testing
@testable import RHOIDS

@MainActor
struct TimerViewModelProgressTests {

    // MARK: - Progress calculation edge cases

    @Test("progress is 0 when plannedDuration is 0 (division by zero guard)")
    func progressZeroDuration() {
        let vm = makeViewModel()
        vm.plannedDuration = 0
        vm.elapsed = 100
        #expect(vm.progress == 0,
                "Zero planned duration should return 0, not NaN or crash")
    }

    @Test("progress is 0 when elapsed is 0")
    func progressZeroElapsed() {
        let vm = makeViewModel()
        vm.plannedDuration = 180
        vm.elapsed = 0
        #expect(vm.progress == 0)
    }

    @Test("progress is 0.5 at midpoint")
    func progressAtMidpoint() {
        let vm = makeViewModel()
        vm.plannedDuration = 200
        vm.elapsed = 100
        #expect(vm.progress == 0.5)
    }

    @Test("progress is clamped to 1 when elapsed exceeds duration")
    func progressClampedAtOne() {
        let vm = makeViewModel()
        vm.plannedDuration = 180
        vm.elapsed = 300
        #expect(vm.progress == 1.0,
                "Overshooting elapsed should clamp at 1.0, not exceed it")
    }

    @Test("progress is clamped to 0 for negative elapsed")
    func progressClampedAtZeroForNegative() {
        let vm = makeViewModel()
        vm.plannedDuration = 180
        vm.elapsed = -10
        #expect(vm.progress == 0,
                "Negative elapsed should clamp at 0")
    }

    @Test("progress with very small duration is accurate")
    func progressSmallDuration() {
        let vm = makeViewModel()
        vm.plannedDuration = 1
        vm.elapsed = 0.5
        #expect(vm.progress == 0.5)
    }

    // MARK: - safeEndDate

    @Test("safeEndDate returns endDate when endDate is in the future")
    func safeEndDateFuture() {
        let vm = makeViewModel()
        let future = Date().addingTimeInterval(120)
        vm.endDate = future
        #expect(vm.safeEndDate == future)
    }

    @Test("safeEndDate returns current time or later when endDate is in the past")
    func safeEndDatePast() {
        let vm = makeViewModel()
        let past = Date().addingTimeInterval(-60)
        vm.endDate = past
        #expect(vm.safeEndDate >= Date().addingTimeInterval(-1),
                "safeEndDate should never return a past date")
    }

    @Test("safeEndDate handles distantFuture (default value)")
    func safeEndDateDistantFuture() {
        let vm = makeViewModel()
        // endDate defaults to .distantFuture
        #expect(vm.safeEndDate == .distantFuture)
    }

    // MARK: - Initial state

    @Test("Fresh TimerViewModel starts with zero elapsed")
    func initialElapsed() {
        let vm = makeViewModel()
        #expect(vm.elapsed == 0)
    }

    @Test("Fresh TimerViewModel has no outcome")
    func initialOutcome() {
        let vm = makeViewModel()
        #expect(vm.outcome == nil)
    }

    @Test("Fresh TimerViewModel has shouldDismiss false")
    func initialShouldDismiss() {
        let vm = makeViewModel()
        #expect(vm.shouldDismiss == false)
    }

    @Test("Fresh TimerViewModel has isCountdownFrozen false")
    func initialIsCountdownFrozen() {
        let vm = makeViewModel()
        #expect(vm.isCountdownFrozen == false)
    }

    @Test("Fresh TimerViewModel has frozenRemaining nil")
    func initialFrozenRemaining() {
        let vm = makeViewModel()
        #expect(vm.frozenRemaining == nil)
    }

    @Test("Fresh TimerViewModel has empty presetName")
    func initialPresetName() {
        let vm = makeViewModel()
        #expect(vm.presetName == "")
    }

    // MARK: - Frozen countdown behavior

    @Test("stopTimer sets isCountdownFrozen to true")
    func stopTimerFreezes() {
        let vm = makeViewModel()
        vm.plannedDuration = 180
        vm.elapsed = 60
        vm.startDate = Date().addingTimeInterval(-60)
        vm.endDate = Date().addingTimeInterval(120)

        vm.stopTimer()

        #expect(vm.isCountdownFrozen == true,
                "Stopping should freeze the display so it doesn't keep ticking")
    }

    @Test("stopTimer sets frozenRemaining to a non-nil value")
    func stopTimerSetsFrozenRemaining() throws {
        let vm = makeViewModel()
        vm.plannedDuration = 180
        vm.startDate = Date().addingTimeInterval(-60)
        vm.endDate = Date().addingTimeInterval(120)

        vm.stopTimer()

        let frozenRemaining = try #require(vm.frozenRemaining)
        #expect(frozenRemaining >= 0, "Frozen remaining should never be negative")
    }

    // MARK: - Helpers

    private func makeViewModel() -> TimerViewModel {
        TimerViewModel(
            timerService: TimerService(
                notificationService: NotificationService(),
                liveActivityService: LiveActivityService(),
                sharedStateService: SharedStateService(suiteName: "com.test.rhoids.tvmprog-\(UUID().uuidString)"),
                alarmPlayer: AlarmPlayer(),
                alarmKitService: AlarmKitService(),
                screenTimeSessionScheduling: NoOpScreenTimeSessionScheduling(),
                sideEffectsEnabled: false
            ),
            alarmPlayer: AlarmPlayer(),
            sharedStateService: SharedStateService(suiteName: "com.test.rhoids.tvmprog-\(UUID().uuidString)"),
            liveActivityService: LiveActivityService(),
            alarmKitService: AlarmKitService(),
            screenTimeService: ScreenTimeService()
        )
    }
}
