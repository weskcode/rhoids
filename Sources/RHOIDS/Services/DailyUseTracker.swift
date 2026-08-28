import Foundation

@MainActor
@Observable
final class DailyUseTracker {
    static let lastUseDateKey = "dailyUse.lastDate.v1"
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

    @discardableResult
    func registerUse(on date: Date = Date()) -> Int {
        let today = calendar.startOfDay(for: date)
        let lastUse = defaults.object(forKey: Self.lastUseDateKey) as? Date

        if let lastUse {
            let lastDay = calendar.startOfDay(for: lastUse)
            guard lastDay != today else { return currentStreak }

            if calendar.date(byAdding: .day, value: 1, to: lastDay) == today {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        defaults.set(today, forKey: Self.lastUseDateKey)
        defaults.set(currentStreak, forKey: Self.currentStreakKey)
        defaults.set(longestStreak, forKey: Self.longestStreakKey)
        return currentStreak
    }
}
