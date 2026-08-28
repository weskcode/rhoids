import Testing
import Foundation
@testable import RHOIDSWatch

@MainActor
struct WatchTimerViewModelTests {

    // MARK: - Progress Calculation

    @Test("Progress is zero when plannedDuration is zero")
    func progressZeroWhenNoDuration() {
        let vm = makeViewModel()
        vm.plannedDuration = 0
        vm.elapsed = 0
        #expect(vm.progress == 0, "progress should be 0 when no duration is set")
    }

    @Test("Progress tracks elapsed vs planned duration",
          arguments: [
            (elapsed: 30.0, planned: 60.0, expected: 0.5),
            (elapsed: 0.0, planned: 180.0, expected: 0.0),
            (elapsed: 180.0, planned: 180.0, expected: 1.0),
            (elapsed: 60.0, planned: 300.0, expected: 0.2),
          ])
    func progressCalculation(elapsed: Double, planned: Double, expected: Double) {
        let vm = makeViewModel()
        vm.elapsed = elapsed
        vm.plannedDuration = planned
        #expect(vm.progress == expected, "progress should be \(expected) for elapsed=\(elapsed), planned=\(planned)")
    }

    @Test("Progress clamps to 0...1 range")
    func progressClamped() {
        let vm = makeViewModel()
        vm.plannedDuration = 60

        vm.elapsed = -10
        #expect(vm.progress == 0, "progress should clamp negative elapsed to 0")

        vm.elapsed = 120
        #expect(vm.progress == 1, "progress should clamp over-elapsed to 1")
    }

    @Test("Remaining progress drains from one to zero")
    func remainingProgressCalculation() {
        let vm = makeViewModel()
        vm.plannedDuration = 100

        vm.elapsed = 0
        #expect(vm.remainingProgress == 1)

        vm.elapsed = 40
        #expect(vm.remainingProgress == 0.6)

        vm.elapsed = 100
        #expect(vm.remainingProgress == 0)
    }

    // MARK: - Safe End Date

    @Test("safeEndDate never returns a date in the past")
    func safeEndDateNeverPast() {
        let vm = makeViewModel()
        vm.endDate = Date().addingTimeInterval(-100)
        #expect(vm.safeEndDate >= Date().addingTimeInterval(-1),
                "safeEndDate should be >= now (within tolerance)")
    }

    @Test("safeEndDate returns future date unchanged")
    func safeEndDatePreservesFuture() {
        let vm = makeViewModel()
        let future = Date().addingTimeInterval(300)
        vm.endDate = future
        #expect(vm.safeEndDate == future,
                "safeEndDate should return a future date as-is")
    }

    // MARK: - Initial State

    @Test("Initial state has safe defaults")
    func initialStateDefaults() {
        let vm = makeViewModel()
        #expect(vm.elapsed == 0)
        #expect(vm.plannedDuration == 0)
        #expect(vm.presetName == "")
        #expect(vm.presetIcon == "")
        #expect(vm.isComplete == false)
        #expect(vm.isCancelled == false)
        #expect(vm.completionQuip == "")
    }

    // MARK: - State Mutation (simulating what WatchHomeView does)

    @Test("Setting ViewModel state synchronously works for race condition prevention")
    func synchronousStateSetup() {
        let vm = makeViewModel()
        let endDate = Date().addingTimeInterval(180)
        let preset = PresetTimer.recommended

        vm.endDate = endDate
        vm.plannedDuration = 180
        vm.presetName = preset.name
        vm.presetIcon = preset.systemImage

        #expect(vm.endDate == endDate)
        #expect(vm.plannedDuration == 180)
        #expect(vm.presetName == "Recommended")
        #expect(vm.presetIcon == preset.systemImage)
        #expect(vm.progress == 0, "progress should be 0 at start")
    }

    // MARK: - Helpers

    /// Creates a ViewModel with a real WatchTimerService.
    /// Since we only test computed properties and state, the service
    /// is not exercised (no start/stop calls).
    private func makeViewModel() -> WatchTimerViewModel {
        let connectivity = WatchConnectivityService()
        let service = WatchTimerService(connectivityService: connectivity)
        let vm = WatchTimerViewModel(timerService: service)
        // Cancel the observer task immediately - we don't want background work
        // interfering with property-level tests.
        vm.cancelObserver()
        return vm
    }
}
