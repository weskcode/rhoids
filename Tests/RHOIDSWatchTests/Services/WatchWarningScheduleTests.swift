import Testing
import Foundation
@testable import RHOIDSWatch

extension Tag {
    /// Tests covering the warning-haptic ("reminder") cadence the user selects.
    @Tag static var reminders: Self
}

/// Verifies the warning-haptic cadence the user selects in Settings
/// (`WarningMode.endOnly` vs `.recurring`) across fresh timers and timers
/// adopted partway through from the iPhone.
@Suite("Watch warning schedule", .tags(.reminders))
struct WatchWarningScheduleTests {

    // MARK: - Recurring ("Every 30 Seconds")

    @Test("Recurring mode fires at every 30s boundary inside the remaining time",
          arguments: [
            // (remainingAtStart, expected beep marks in seconds-remaining)
            (start: 180.0, expected: [150, 120, 90, 60, 30]),   // fresh Recommended
            (start: 300.0, expected: [270, 240, 210, 180, 150, 120, 90, 60, 30]), // fresh Max
            (start: 60.0,  expected: [30]),
            (start: 30.0,  expected: []),                        // exactly 30s: nothing inside
            (start: 20.0,  expected: []),                        // shorter than one boundary
            (start: 1.0,   expected: []),
            (start: 0.0,   expected: []),
          ])
    func recurringCadence(start: Double, expected: [Int]) {
        verifyFired(remainingAtStart: start, mode: .recurring, expected: expected)
    }

    @Test("Recurring mode keeps every reminder when adopting a timer mid-run",
          arguments: [
            // Regression: the old adopt() path mis-marked boundaries off `elapsed`
            // and skipped - or entirely dropped - upcoming reminders.
            (start: 100.0, expected: [90, 60, 30]),  // old code produced [60, 30]
            (start: 95.0,  expected: [90, 60, 30]),
            (start: 90.0,  expected: [60, 30]),       // on a boundary → step inside
            (start: 125.0, expected: [120, 90, 60, 30]),
            (start: 179.0, expected: [150, 120, 90, 60, 30]), // adopted at full duration → all fire
          ])
    func recurringAdoptionLosesNoReminders(start: Double, expected: [Int]) {
        verifyFired(remainingAtStart: start, mode: .recurring, expected: expected)
    }

    // MARK: - End Only

    @Test("End-only mode fires a single reminder at T-30 (or at start if shorter)",
          arguments: [
            (start: 180.0, expected: [30]),
            (start: 300.0, expected: [30]),
            (start: 100.0, expected: [30]),  // adopted mid-run still beeps once at 30
            (start: 30.0,  expected: [30]),
            (start: 25.0,  expected: [25]),  // shorter than 30s → remind at start
            (start: 1.0,   expected: [1]),
            (start: 0.0,   expected: []),
          ])
    func endOnlyCadence(start: Double, expected: [Int]) {
        verifyFired(remainingAtStart: start, mode: .endOnly, expected: expected)
    }

    // MARK: - White-box behaviour

    @Test("Initial nextBeepAt reflects the selected mode",
          arguments: [
            (start: 180.0, mode: WarningMode.recurring, expected: 150.0),
            (start: 90.0,  mode: WarningMode.recurring, expected: 60.0),  // steps inside the boundary
            (start: 20.0,  mode: WarningMode.recurring, expected: 0.0),
            (start: 180.0, mode: WarningMode.endOnly,   expected: 30.0),
            (start: 25.0,  mode: WarningMode.endOnly,   expected: 25.0),
          ])
    func initialThreshold(start: Double, mode: WarningMode, expected: Double) {
        let schedule = WatchWarningSchedule(remainingAtStart: start, mode: mode)
        #expect(schedule.nextBeepAt == expected,
                "nextBeepAt should be \(expected) for start=\(start), mode=\(mode.rawValue)")
    }

    // Note: `shouldBeep` is `mutating`, so it can't be called directly inside
    // `#expect` (the macro captures the value immutably). Capture results first.

    @Test("No reminder fires before the first boundary is reached")
    func noBeepBeforeFirstBoundary() {
        var schedule = WatchWarningSchedule(remainingAtStart: 180, mode: .recurring)
        let at179 = schedule.shouldBeep(remaining: 179)
        let at151 = schedule.shouldBeep(remaining: 151)
        #expect(at179 == false)
        #expect(at151 == false)
        #expect(schedule.nextBeepAt == 150, "threshold should not advance until it fires")
    }

    @Test("A boundary fires exactly once even across several sub-boundary ticks")
    func boundaryFiresOnce() {
        var schedule = WatchWarningSchedule(remainingAtStart: 180, mode: .recurring)
        let firstBoundary = schedule.shouldBeep(remaining: 150)
        let belowFirst = schedule.shouldBeep(remaining: 149.5)
        let beforeSecond = schedule.shouldBeep(remaining: 121)
        let secondBoundary = schedule.shouldBeep(remaining: 120)
        #expect(firstBoundary, "150s boundary should fire")
        #expect(belowFirst == false, "150s boundary should not fire twice")
        #expect(beforeSecond == false)
        #expect(secondBoundary, "120s boundary should fire")
    }

    @Test("End-only retires after its single reminder")
    func endOnlyRetires() {
        var schedule = WatchWarningSchedule(remainingAtStart: 180, mode: .endOnly)
        let before = schedule.shouldBeep(remaining: 31)
        let atBoundary = schedule.shouldBeep(remaining: 30)
        let justAfter = schedule.shouldBeep(remaining: 29)
        let muchLater = schedule.shouldBeep(remaining: 5)
        #expect(before == false)
        #expect(atBoundary, "the single end-only reminder should fire at T-30")
        #expect(justAfter == false, "end-only should not fire again")
        #expect(muchLater == false)
        #expect(schedule.nextBeepAt == 0)
    }

    // MARK: - Helpers

    /// Drives a schedule from `remainingAtStart` down to zero one second at a
    /// time - exactly as the countdown loop does - and asserts the seconds-
    /// remaining at which a reminder fired.
    private func verifyFired(
        remainingAtStart: TimeInterval,
        mode: WarningMode,
        expected: [Int],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var schedule = WatchWarningSchedule(remainingAtStart: remainingAtStart, mode: mode)
        var fired: [Int] = []
        var second = Int(remainingAtStart)
        while second > 0 {
            let boundary = Int(schedule.nextBeepAt)
            if schedule.shouldBeep(remaining: TimeInterval(second)) {
                fired.append(boundary)
            }
            second -= 1
        }
        #expect(fired == expected,
                "fired \(fired) but expected \(expected) for start=\(remainingAtStart), mode=\(mode.rawValue)",
                sourceLocation: sourceLocation)
    }
}
