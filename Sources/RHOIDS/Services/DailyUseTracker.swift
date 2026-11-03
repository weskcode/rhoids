import Foundation

@MainActor
@Observable
final class DailyUseTracker {
    static let lastUseYearKey = "dailyUse.lastYear.v1"
    static let lastUseMonthKey = "dailyUse.lastMonth.v1"
    static let lastUseDayKey = "dailyUse.lastDay.v1"
    static let currentStreakKey = "dailyUse.currentStreak.v1"
    static let longestStreakKey = "dailyUse.longestStreak.v1"

    private let defaults: UserDefaults
    private let calendar: Calendar

    private(set) var currentStreak: Int
    private(set) var longestStreak: Int

    init(defaults: UserDefaults = .standard, calendar: Calendar = .autoupdatingCurrent) {
        self.defaults = defaults
        self.calendar = calendar
        self.currentStreak = defaults.integer(forKey: Self.currentStreakKey)
        self.longestStreak = defaults.integer(forKey: Self.longestStreakKey)
    }

    /// A calendar day frozen as plain (year, month, day) integers at the
    /// moment it was recorded. Deliberately not a `Date`: `calendar`
    /// defaults to `.autoupdatingCurrent`, whose time zone reflects
    /// whatever the system's zone is *when read*, not when a previous
    /// `registerUse` ran. A stored `Date` re-interpreted later under a
    /// different zone (e.g. a flight lands and the device updates its zone
    /// mid-session) can silently map to the wrong calendar day; a frozen
    /// (Y, M, D) triple cannot be reinterpreted at all.
    private struct DayKey: Equatable {
        let year: Int
        let month: Int
        let day: Int
    }

    private func dayKey(for date: Date) -> DayKey {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return DayKey(year: components.year!, month: components.month!, day: components.day!)
    }

    /// Whether `key` is exactly one calendar day after `previous`. Uses a
    /// fixed UTC calendar for the arithmetic itself - `previous` and `key`
    /// are already zone-free (Y, M, D) triples, so the day-boundary math
    /// must not be re-exposed to the live device time zone.
    private func isNextDay(_ key: DayKey, after previous: DayKey) -> Bool {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        guard let previousDate = utc.date(
            from: DateComponents(year: previous.year, month: previous.month, day: previous.day)
        ), let nextDate = utc.date(byAdding: .day, value: 1, to: previousDate) else {
            return false
        }
        let nextKey = DayKey(
            year: utc.component(.year, from: nextDate),
            month: utc.component(.month, from: nextDate),
            day: utc.component(.day, from: nextDate)
        )
        return nextKey == key
    }

    private func storedDayKey() -> DayKey? {
        guard defaults.object(forKey: Self.lastUseYearKey) != nil else { return nil }
        return DayKey(
            year: defaults.integer(forKey: Self.lastUseYearKey),
            month: defaults.integer(forKey: Self.lastUseMonthKey),
            day: defaults.integer(forKey: Self.lastUseDayKey)
        )
    }

    private func setStoredDayKey(_ key: DayKey) {
        defaults.set(key.year, forKey: Self.lastUseYearKey)
        defaults.set(key.month, forKey: Self.lastUseMonthKey)
        defaults.set(key.day, forKey: Self.lastUseDayKey)
    }

    @discardableResult
    func registerUse(on date: Date = Date()) -> Int {
        let today = dayKey(for: date)

        if let lastDay = storedDayKey() {
            guard lastDay != today else { return currentStreak }

            if isNextDay(today, after: lastDay) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        setStoredDayKey(today)
        defaults.set(currentStreak, forKey: Self.currentStreakKey)
        defaults.set(longestStreak, forKey: Self.longestStreakKey)
        return currentStreak
    }
}
