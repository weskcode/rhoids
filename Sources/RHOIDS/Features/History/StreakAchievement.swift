import Foundation

struct StreakAchievement: Identifiable, Equatable {
    let days: Int
    let title: LocalizedStringResource
    let systemImage: String

    var id: Int { days }

    static let all: [StreakAchievement] = [
        .init(days: 3, title: "Getting Started", systemImage: "sparkles"),
        .init(days: 7, title: "One Week", systemImage: "calendar"),
        .init(days: 14, title: "Two Weeks", systemImage: "calendar.badge.checkmark"),
        .init(days: 30, title: "One Month", systemImage: "flame"),
        .init(days: 60, title: "Strong Habit", systemImage: "bolt.heart"),
        .init(days: 100, title: "Century", systemImage: "trophy"),
        .init(days: 365, title: "One Year", systemImage: "medal")
    ]
}
