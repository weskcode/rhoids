import Foundation
import Testing
@testable import RHOIDS

@MainActor
struct DailyUseTrackerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "com.test.rhoids.daily-use-\(UUID().uuidString)")!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func `First use starts a one day streak`() {
        let sut = DailyUseTracker(defaults: freshDefaults(), calendar: calendar)

        #expect(sut.registerUse(on: date(2026, 7, 1)) == 1)
        #expect(sut.longestStreak == 1)
    }

    @Test func `Multiple opens on the same day count once`() {
        let sut = DailyUseTracker(defaults: freshDefaults(), calendar: calendar)

        sut.registerUse(on: date(2026, 7, 1, hour: 8))
        sut.registerUse(on: date(2026, 7, 1, hour: 22))

        #expect(sut.currentStreak == 1)
    }

    @Test func `Consecutive calendar days extend the streak`() {
        let sut = DailyUseTracker(defaults: freshDefaults(), calendar: calendar)

        sut.registerUse(on: date(2026, 7, 1))
        sut.registerUse(on: date(2026, 7, 2))
        sut.registerUse(on: date(2026, 7, 3))

        #expect(sut.currentStreak == 3)
        #expect(sut.longestStreak == 3)
    }

    @Test func `Streak continues across month and year boundaries`() {
        let sut = DailyUseTracker(defaults: freshDefaults(), calendar: calendar)

        sut.registerUse(on: date(2026, 12, 31))
        sut.registerUse(on: date(2027, 1, 1))

        #expect(sut.currentStreak == 2)
    }

    @Test func `Calendar-day streak survives daylight saving transition`() {
        var easternCalendar = Calendar(identifier: .gregorian)
        easternCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        let sut = DailyUseTracker(defaults: freshDefaults(), calendar: easternCalendar)
        let beforeChange = easternCalendar.date(
            from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)
        )!
        let afterChange = easternCalendar.date(
            from: DateComponents(year: 2026, month: 3, day: 8, hour: 23)
        )!

        sut.registerUse(on: beforeChange)
        sut.registerUse(on: afterChange)

        #expect(sut.currentStreak == 2)
    }

    @Test func `Missed day resets current streak and preserves best streak`() {
        let sut = DailyUseTracker(defaults: freshDefaults(), calendar: calendar)

        sut.registerUse(on: date(2026, 7, 1))
        sut.registerUse(on: date(2026, 7, 2))
        sut.registerUse(on: date(2026, 7, 4))

        #expect(sut.currentStreak == 1)
        #expect(sut.longestStreak == 2)
    }

    @Test func `Streak state persists across launches`() {
        let defaults = freshDefaults()
        let first = DailyUseTracker(defaults: defaults, calendar: calendar)
        first.registerUse(on: date(2026, 7, 1))
        first.registerUse(on: date(2026, 7, 2))

        let relaunched = DailyUseTracker(defaults: defaults, calendar: calendar)
        #expect(relaunched.currentStreak == 2)
        #expect(relaunched.longestStreak == 2)
    }

    @Test func `Achievement tiers are ordered and stable`() {
        #expect(StreakAchievement.all.map(\.days) == [3, 7, 14, 30, 60, 100, 365])
        #expect(Set(StreakAchievement.all.map(\.id)).count == StreakAchievement.all.count)
    }
}
