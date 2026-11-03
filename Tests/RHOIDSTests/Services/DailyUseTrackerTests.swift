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

    @Test func `A device time zone change between calls does not fabricate a day`() {
        // Regression test: the stored "last use" used to be a raw `Date`,
        // re-interpreted through whichever calendar/time zone happened to
        // be live when it was read back. With `.autoupdatingCurrent` (the
        // real default), a time zone change between two calls - e.g. a
        // flight landing - could make the previous instant appear to fall
        // on a different calendar day than it did when it was recorded,
        // fabricating or swallowing a day. The fix freezes (year, month,
        // day) at write time instead of storing a reinterpretable `Date`.
        let defaults = freshDefaults()

        var aucklandCalendar = Calendar(identifier: .gregorian)
        aucklandCalendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        let beforeFlight = DailyUseTracker(defaults: defaults, calendar: aucklandCalendar)

        // 23:00 NZDT on Jan 10 - local day is Jan 10.
        let departure = aucklandCalendar.date(
            from: DateComponents(year: 2026, month: 1, day: 10, hour: 23)
        )!
        #expect(beforeFlight.registerUse(on: departure) == 1)

        // Only one real hour later, but the device's time zone has since
        // changed to Los Angeles (simulating landing mid-flight); a fresh
        // DailyUseTracker picks up the new live zone the same way the real
        // app's `.autoupdatingCurrent` calendar would.
        var losAngelesCalendar = Calendar(identifier: .gregorian)
        losAngelesCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let afterFlight = DailyUseTracker(defaults: defaults, calendar: losAngelesCalendar)
        let oneHourLater = departure.addingTimeInterval(3600)

        #expect(
            afterFlight.registerUse(on: oneHourLater) == 1,
            "Only ~1 hour of real time passed; the streak must not advance just because the time zone changed"
        )
        #expect(afterFlight.longestStreak == 1)
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
