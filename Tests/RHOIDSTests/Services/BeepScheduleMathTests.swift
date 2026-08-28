import Foundation
import Testing
@testable import RHOIDS

/// Tests the beep scheduling math used by TimerService's countdown task.
/// The beep schedule logic is embedded in startCountdownTask, but we can
/// verify the same algorithm here to catch off-by-one errors, boundary
/// conditions, and edge cases that would cause missed or double beeps.
struct BeepScheduleMathTests {

    // MARK: - endOnly mode: single beep at T-30

    @Test("endOnly mode: beep at T-30 for standard 180s timer")
    func endOnlyStandard180() {
        let (nextBeepAt, _) = calculateFirstBeep(duration: 180, mode: .endOnly)
        #expect(nextBeepAt == 30,
                "180s timer should beep when 30s remains")
    }

    @Test("endOnly mode: beep capped at duration for short timer")
    func endOnlyShortTimer() {
        let (nextBeepAt, _) = calculateFirstBeep(duration: 20, mode: .endOnly)
        #expect(nextBeepAt == 20,
                "20s timer should beep immediately (min(30, 20) = 20)")
    }

    @Test("endOnly mode: beep at 30 for exactly 30s timer")
    func endOnlyExactly30() {
        let (nextBeepAt, _) = calculateFirstBeep(duration: 30, mode: .endOnly)
        #expect(nextBeepAt == 30,
                "30s timer: min(30, 30) = 30")
    }

    @Test("endOnly mode: beep at 30 for 300s timer")
    func endOnly300s() {
        let (nextBeepAt, _) = calculateFirstBeep(duration: 300, mode: .endOnly)
        #expect(nextBeepAt == 30)
    }

    @Test("endOnly mode: beep at 1 for 1s timer")
    func endOnly1s() {
        let (nextBeepAt, _) = calculateFirstBeep(duration: 1, mode: .endOnly)
        #expect(nextBeepAt == 1)
    }

    // MARK: - recurring mode: beep every 30s

    @Test("recurring mode: first beep at 150s for 180s timer")
    func recurringStandard180() {
        let (nextBeepAt, allBeeps) = calculateFirstBeep(duration: 180, mode: .recurring)
        #expect(nextBeepAt == 150,
                "180s timer: floor(180/30)*30 = 180, minus 30 = 150")
        #expect(allBeeps == [150, 120, 90, 60, 30])
    }

    @Test("recurring mode: first beep at 270s for 300s timer")
    func recurringStandard300() {
        let (nextBeepAt, allBeeps) = calculateFirstBeep(duration: 300, mode: .recurring)
        #expect(nextBeepAt == 270)
        #expect(allBeeps == [270, 240, 210, 180, 150, 120, 90, 60, 30])
    }

    @Test("recurring mode: handles 60s timer (2 boundaries)")
    func recurring60s() {
        let (nextBeepAt, allBeeps) = calculateFirstBeep(duration: 60, mode: .recurring)
        #expect(nextBeepAt == 30,
                "60s timer: floor(60/30)*30 = 60, minus 30 = 30")
        #expect(allBeeps == [30])
    }

    @Test("recurring mode: handles 90s timer")
    func recurring90s() {
        let (nextBeepAt, allBeeps) = calculateFirstBeep(duration: 90, mode: .recurring)
        #expect(nextBeepAt == 60,
                "90s timer: floor(90/30)*30 = 90, minus 30 = 60")
        #expect(allBeeps == [60, 30])
    }

    @Test("recurring mode: handles 31s timer")
    func recurring31s() {
        let (nextBeepAt, allBeeps) = calculateFirstBeep(duration: 31, mode: .recurring)
        // floor(31/30)*30 = 30, 30 >= 31 is false so no subtract → beep at 30s remaining
        #expect(nextBeepAt == 30)
        #expect(allBeeps == [30])
    }

    @Test("recurring mode: handles 30s timer (edge case)")
    func recurring30s() {
        let (nextBeepAt, allBeeps) = calculateFirstBeep(duration: 30, mode: .recurring)
        // floor(30/30)*30 = 30, which >= 30, so subtract: 0
        #expect(nextBeepAt == 0)
        #expect(allBeeps.isEmpty,
                "30s timer in recurring mode has no boundary to beep at")
    }

    @Test("recurring mode: handles 10s timer")
    func recurring10s() {
        let (nextBeepAt, _) = calculateFirstBeep(duration: 10, mode: .recurring)
        // floor(10/30)*30 = 0, which >= 10? No. 0 < 10.
        // But then nextBeepAt = 0, and 0 >= duration is false, so no subtract.
        // Actually: floor(10/30) = 0, so 0*30 = 0. 0 >= 10 is false. nextBeepAt = 0.
        #expect(nextBeepAt == 0)
    }

    // MARK: - beep notification count (NotificationService.scheduleBeepNotifications)

    @Test("Beep notification count for 180s timer is 4")
    func beepNotificationCount180() {
        // Boundaries: at 30s, 60s, 90s, 120s from start
        // That's 150s, 120s, 90s, 60s remaining
        // The final 30s is handled by the warning notification, not beeps
        let count = calculateBeepNotificationCount(duration: 180)
        #expect(count == 4)
    }

    @Test("Beep notification count for 300s timer is 8")
    func beepNotificationCount300() {
        // 30, 60, 90, 120, 150, 180, 210, 240 seconds from start
        // = 270, 240, 210, 180, 150, 120, 90, 60 remaining
        let count = calculateBeepNotificationCount(duration: 300)
        #expect(count == 8)
    }

    @Test("Beep notification count for 60s timer is 0")
    func beepNotificationCount60() {
        // Only boundary is at 30s from start, but 60-30=30 remaining
        // condition: secondsFromStart < duration - 30 → 30 < 30 is false
        let count = calculateBeepNotificationCount(duration: 60)
        #expect(count == 0)
    }

    @Test("Beep notification count for 90s timer is 1")
    func beepNotificationCount90() {
        // 30s from start → 60s remaining. 30 < 60: yes
        // 60s from start → 30s remaining. 60 < 60: no (the warning handles T-30)
        let count = calculateBeepNotificationCount(duration: 90)
        #expect(count == 1)
    }

    @Test("Beep notification count for 30s timer is 0")
    func beepNotificationCount30() {
        let count = calculateBeepNotificationCount(duration: 30)
        #expect(count == 0)
    }

    @Test("Beep notification count for 1s timer is 0")
    func beepNotificationCount1() {
        let count = calculateBeepNotificationCount(duration: 1)
        #expect(count == 0)
    }

    // MARK: - Helpers

    /// Mirrors the beep calculation from TimerService.startCountdownTask
    private func calculateFirstBeep(duration: TimeInterval, mode: WarningMode) -> (nextBeepAt: TimeInterval, allBeeps: [TimeInterval]) {
        var nextBeepAt: TimeInterval
        if mode == .endOnly {
            nextBeepAt = min(30, duration)
            return (nextBeepAt, nextBeepAt > 0 ? [nextBeepAt] : [])
        } else {
            nextBeepAt = floor(duration / 30) * 30
            if nextBeepAt >= duration { nextBeepAt -= 30 }

            var beeps: [TimeInterval] = []
            var current = nextBeepAt
            while current > 0 {
                beeps.append(current)
                current -= 30
            }
            return (nextBeepAt, beeps)
        }
    }

    /// Mirrors NotificationService.scheduleBeepNotifications boundary calculation
    private func calculateBeepNotificationCount(duration: TimeInterval) -> Int {
        var secondsFromStart: TimeInterval = 30
        var count = 0
        while secondsFromStart < duration - 30 {
            count += 1
            secondsFromStart += 30
        }
        return count
    }
}
