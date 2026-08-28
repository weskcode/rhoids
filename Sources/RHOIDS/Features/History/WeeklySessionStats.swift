import Foundation

struct WeeklySessionStats {
    let count: Int
    let averageDuration: TimeInterval

    static func calculate(
        sessions: [TimerSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklySessionStats {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        var count = 0
        var totalDuration: TimeInterval = 0

        for session in sessions where session.startedAt >= weekAgo {
            count += 1
            totalDuration += session.actualDuration
        }

        return WeeklySessionStats(
            count: count,
            averageDuration: count == 0 ? 0 : totalDuration / Double(count)
        )
    }
}
