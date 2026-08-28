import Foundation
import Testing
@testable import RHOIDS

struct TimerSessionDataIntegrityTests {

    // MARK: - actualDuration edge cases

    @Test("actualDuration falls back to plannedDuration when endedAt is nil")
    func actualDurationFallback() {
        let session = TimerSession(plannedDuration: 180, endedAt: nil)
        #expect(session.actualDuration == 180)
    }

    @Test("actualDuration computes correctly when session ended early")
    func actualDurationEarlyEnd() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let session = TimerSession(
            startedAt: start,
            plannedDuration: 300,
            endedAt: start.addingTimeInterval(120)
        )
        #expect(session.actualDuration == 120,
                "Should reflect actual elapsed time, not planned duration")
    }

    @Test("actualDuration clamps to plannedDuration when endedAt overruns the planned end")
    func actualDurationOverrunClamped() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let session = TimerSession(
            startedAt: start,
            plannedDuration: 180,
            endedAt: start.addingTimeInterval(240)
        )
        #expect(session.actualDuration == 180,
                "A timer can't run past its planned end - overrun is a recording artifact")
    }

    @Test("actualDuration clamps a stale session recorded days after its planned end")
    func actualDurationStaleSessionClamped() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let session = TimerSession(
            startedAt: start,
            plannedDuration: 180,
            endedAt: start.addingTimeInterval(7 * 86_400)
        )
        #expect(session.actualDuration == 180,
                "A timer completed days late must not report a multi-day duration")
    }

    @Test("actualDuration handles endedAt equal to startedAt (zero elapsed)")
    func actualDurationZeroElapsed() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let session = TimerSession(
            startedAt: start,
            plannedDuration: 180,
            endedAt: start
        )
        #expect(session.actualDuration == 0)
    }

    @Test("actualDuration clamps to zero when endedAt is before startedAt")
    func actualDurationNegativeClampedToZero() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let session = TimerSession(
            startedAt: start,
            plannedDuration: 180,
            endedAt: start.addingTimeInterval(-60)
        )
        #expect(session.actualDuration == 0,
                "endedAt before startedAt is corrupt data - report zero, not negative time")
    }

    // MARK: - Initialization defaults

    @Test("Default id is unique per instance")
    func defaultIdIsUnique() {
        let a = TimerSession(plannedDuration: 180)
        let b = TimerSession(plannedDuration: 180)
        #expect(a.id != b.id)
    }

    @Test("Default startedAt is approximately now")
    func defaultStartedAtIsNow() {
        let before = Date()
        let session = TimerSession(plannedDuration: 180)
        let after = Date()
        #expect(session.startedAt >= before)
        #expect(session.startedAt <= after)
    }

    @Test("Default wasInterrupted is false")
    func defaultWasInterrupted() {
        let session = TimerSession(plannedDuration: 180)
        #expect(session.wasInterrupted == false)
    }

    @Test("Default endedAt is nil")
    func defaultEndedAt() {
        let session = TimerSession(plannedDuration: 180)
        #expect(session.endedAt == nil)
    }

    @Test("Default presetName is nil")
    func defaultPresetName() {
        let session = TimerSession(plannedDuration: 180)
        #expect(session.presetName == nil)
    }

    // MARK: - Extreme values

    @Test("Session with zero planned duration does not crash")
    func zeroPlannedDuration() {
        let session = TimerSession(plannedDuration: 0)
        #expect(session.actualDuration == 0)
    }

    @Test("Session with very large planned duration does not crash")
    func veryLargePlannedDuration() {
        let session = TimerSession(plannedDuration: 86400)
        #expect(session.actualDuration == 86400)
    }

    @Test("Session preserves all fields through init")
    func fullInitPreservesAllFields() {
        let id = UUID()
        let start = Date(timeIntervalSinceReferenceDate: 500_000)
        let end = start.addingTimeInterval(180)

        let session = TimerSession(
            id: id,
            startedAt: start,
            plannedDuration: 180,
            endedAt: end,
            wasInterrupted: true,
            presetName: "Recommended"
        )

        #expect(session.id == id)
        #expect(session.startedAt == start)
        #expect(session.plannedDuration == 180)
        #expect(session.endedAt == end)
        #expect(session.wasInterrupted == true)
        #expect(session.presetName == "Recommended")
        #expect(session.actualDuration == 180)
    }

    // MARK: - Weekly stats integration

    @Test("WeeklySessionStats handles sessions with nil endedAt gracefully")
    func weeklyStatsWithNilEndedAt() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let sessions = [
            TimerSession(
                startedAt: now.addingTimeInterval(-3600),
                plannedDuration: 180,
                endedAt: nil
            )
        ]
        let stats = WeeklySessionStats.calculate(sessions: sessions, now: now)
        #expect(stats.count == 1)
        #expect(stats.averageDuration == 180,
                "Should use plannedDuration via actualDuration fallback")
    }

    @Test("WeeklySessionStats handles interrupted sessions")
    func weeklyStatsWithInterruptedSessions() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let start = now.addingTimeInterval(-3600)
        let sessions = [
            TimerSession(
                startedAt: start,
                plannedDuration: 300,
                endedAt: start.addingTimeInterval(45),
                wasInterrupted: true,
                presetName: "Max"
            ),
            TimerSession(
                startedAt: start.addingTimeInterval(600),
                plannedDuration: 180,
                endedAt: start.addingTimeInterval(780),
                wasInterrupted: false,
                presetName: "Recommended"
            )
        ]
        let stats = WeeklySessionStats.calculate(sessions: sessions, now: now)
        #expect(stats.count == 2)
        #expect(stats.averageDuration == (45 + 180) / 2.0)
    }

    @Test("WeeklySessionStats with exactly-7-day-old session excludes it")
    func weeklyStatsBoundary() throws {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let exactlyWeekAgo = try #require(Calendar.current.date(byAdding: .day, value: -7, to: now))
        let sessions = [
            TimerSession(
                startedAt: exactlyWeekAgo.addingTimeInterval(-1),
                plannedDuration: 180,
                endedAt: exactlyWeekAgo.addingTimeInterval(179)
            )
        ]
        let stats = WeeklySessionStats.calculate(sessions: sessions, now: now)
        #expect(stats.count == 0,
                "Session started before the 7-day window should be excluded")
    }

    @Test("WeeklySessionStats with empty array returns zeros")
    func weeklyStatsEmpty() {
        let stats = WeeklySessionStats.calculate(sessions: [])
        #expect(stats.count == 0)
        #expect(stats.averageDuration == 0)
    }
}
