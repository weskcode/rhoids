import Foundation
import Testing
@testable import RHOIDS

struct WeeklySessionStatsTests {
    @Test("calculate counts only sessions in the last seven days")
    func calculateCountsRecentSessions() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let sessions = [
            TimerSession(
                startedAt: now.addingTimeInterval(-60),
                plannedDuration: 180,
                endedAt: now.addingTimeInterval(120)
            ),
            TimerSession(
                startedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
                plannedDuration: 300,
                endedAt: now.addingTimeInterval((-2 * 24 * 60 * 60) + 240)
            ),
            TimerSession(
                startedAt: now.addingTimeInterval(-8 * 24 * 60 * 60),
                plannedDuration: 60,
                endedAt: now.addingTimeInterval((-8 * 24 * 60 * 60) + 60)
            )
        ]

        let stats = WeeklySessionStats.calculate(sessions: sessions, now: now)

        #expect(stats.count == 2)
        #expect(stats.averageDuration == 210)
    }

    @Test("calculate returns zero average with no weekly sessions")
    func calculateHandlesEmptyWeek() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let sessions = [
            TimerSession(
                startedAt: now.addingTimeInterval(-8 * 24 * 60 * 60),
                plannedDuration: 60,
                endedAt: now.addingTimeInterval((-8 * 24 * 60 * 60) + 60)
            )
        ]

        let stats = WeeklySessionStats.calculate(sessions: sessions, now: now)

        #expect(stats.count == 0)
        #expect(stats.averageDuration == 0)
    }

    // MARK: - 7-day boundary (off-by-one guard)

    @Test("Session started exactly seven days ago is included")
    func boundaryInclusive() throws {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let weekAgo = try #require(Calendar.current.date(byAdding: .day, value: -7, to: now))
        let sessions = [
            TimerSession(
                startedAt: weekAgo,
                plannedDuration: 120,
                endedAt: weekAgo.addingTimeInterval(120)
            )
        ]

        let stats = WeeklySessionStats.calculate(sessions: sessions, now: now)

        #expect(stats.count == 1, "A session exactly at the 7-day cutoff must be counted (>= weekAgo)")
        #expect(stats.averageDuration == 120)
    }

    @Test("Session one second before the seven-day cutoff is excluded")
    func boundaryExclusive() throws {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let weekAgo = try #require(Calendar.current.date(byAdding: .day, value: -7, to: now))
        let sessions = [
            TimerSession(
                startedAt: weekAgo.addingTimeInterval(-1),
                plannedDuration: 120,
                endedAt: weekAgo.addingTimeInterval(119)
            )
        ]

        let stats = WeeklySessionStats.calculate(sessions: sessions, now: now)

        #expect(stats.count == 0, "A session one second before the cutoff must be excluded")
        #expect(stats.averageDuration == 0)
    }

    // MARK: - Duration sourcing

    @Test("Interrupted sessions are included and contribute their actual duration")
    func interruptedSessionsCounted() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let sessions = [
            TimerSession(
                startedAt: now.addingTimeInterval(-60),
                plannedDuration: 180,
                endedAt: now.addingTimeInterval(-30),
                wasInterrupted: true
            )
        ]

        let stats = WeeklySessionStats.calculate(sessions: sessions, now: now)

        #expect(stats.count == 1, "Stopped-early sessions still count toward weekly history")
        #expect(stats.averageDuration == 30)
    }

    @Test("Session without an end date contributes its planned duration")
    func missingEndDateUsesPlanned() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let sessions = [
            TimerSession(
                startedAt: now.addingTimeInterval(-60),
                plannedDuration: 180,
                endedAt: nil
            )
        ]

        let stats = WeeklySessionStats.calculate(sessions: sessions, now: now)

        #expect(stats.count == 1)
        #expect(stats.averageDuration == 180, "actualDuration falls back to plannedDuration when endedAt is nil")
    }
}
