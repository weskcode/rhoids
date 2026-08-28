import Testing
import Foundation
// WatchTimerEntry source is compiled directly into this test target

struct WatchTimerEntryTests {

    // MARK: - Progress Calculation

    @Test("Progress is zero when not running")
    func progressZeroWhenIdle() {
        let entry = WatchTimerEntry.placeholder
        #expect(entry.progress == 0, "idle entry should have 0 progress")
    }

    @Test("Progress is zero when duration is zero")
    func progressZeroWithZeroDuration() {
        let entry = WatchTimerEntry(
            date: Date(),
            isRunning: true,
            endDate: Date().addingTimeInterval(60),
            presetName: "Quick",
            duration: 0
        )
        #expect(entry.progress == 0, "progress should be 0 when duration is 0")
    }

    @Test("Progress calculates correctly for running timer",
          arguments: [
            // (elapsedFraction, totalDuration)
            (0.0, 180.0),   // just started
            (0.5, 180.0),   // halfway
            (1.0, 180.0),   // just finished
          ])
    func progressCalculation(elapsedFraction: Double, totalDuration: Double) {
        let now = Date()
        let elapsed = totalDuration * elapsedFraction
        let remaining = totalDuration - elapsed
        let endDate = now.addingTimeInterval(remaining)

        let entry = WatchTimerEntry(
            date: now,
            isRunning: true,
            endDate: endDate,
            presetName: "Recommended",
            duration: totalDuration
        )

        let expectedProgress = elapsedFraction
        #expect(abs(entry.progress - expectedProgress) < 0.01,
                "progress should be ~\(expectedProgress) but was \(entry.progress)")
    }

    @Test("Progress clamps to 0...1")
    func progressClamped() {
        let now = Date()

        // endDate in the past - timer has overrun
        let pastEntry = WatchTimerEntry(
            date: now,
            isRunning: true,
            endDate: now.addingTimeInterval(-30),
            presetName: "Quick",
            duration: 60
        )
        #expect(pastEntry.progress <= 1, "progress should clamp to max 1")
        #expect(pastEntry.progress >= 0, "progress should never be negative")

        // endDate far in the future - negative elapsed
        let futureEntry = WatchTimerEntry(
            date: now,
            isRunning: true,
            endDate: now.addingTimeInterval(200),
            presetName: "Quick",
            duration: 60
        )
        #expect(futureEntry.progress >= 0, "progress should clamp to min 0")
        #expect(futureEntry.progress <= 1, "progress should never exceed 1")
    }

    // MARK: - Remaining Time

    @Test("Remaining is zero when no endDate")
    func remainingZeroNoEndDate() {
        let entry = WatchTimerEntry.placeholder
        #expect(entry.remaining == 0, "remaining should be 0 with no endDate")
    }

    @Test("Remaining is zero when endDate is in the past")
    func remainingZeroForPastEndDate() {
        let entry = WatchTimerEntry(
            date: Date(),
            isRunning: true,
            endDate: Date().addingTimeInterval(-10),
            presetName: "Quick",
            duration: 60
        )
        #expect(entry.remaining == 0, "remaining should clamp to 0 for past endDate")
    }

    @Test("Remaining reflects time until endDate")
    func remainingReflectsEndDate() {
        let now = Date()
        let endDate = now.addingTimeInterval(120)
        let entry = WatchTimerEntry(
            date: now,
            isRunning: true,
            endDate: endDate,
            presetName: "Recommended",
            duration: 180
        )
        #expect(abs(entry.remaining - 120) < 1,
                "remaining should be ~120 seconds")
    }

    // MARK: - Static Entries

    @Test("Placeholder entry is idle")
    func placeholderIsIdle() {
        let entry = WatchTimerEntry.placeholder
        #expect(entry.isRunning == false)
        #expect(entry.endDate == nil)
        #expect(entry.presetName == nil)
        #expect(entry.duration == 0)
    }

    @Test("Preview running entry is configured correctly")
    func previewRunningIsConfigured() {
        let entry = WatchTimerEntry.previewRunning
        #expect(entry.isRunning == true)
        #expect(entry.endDate != nil)
        #expect(entry.presetName == "Recommended")
        #expect(entry.duration == 180)
        #expect(entry.progress >= 0)
        #expect(entry.progress <= 1)
    }
}
