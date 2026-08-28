import SwiftUI

struct StreakAchievementsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        List {
            Section {
                LabeledContent("Current streak", value: dayCount(currentStreak))
                LabeledContent("Best streak", value: dayCount(longestStreak))
            }

            Section("Achievements") {
                ForEach(StreakAchievement.all) { achievement in
                    achievementRow(achievement)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Streak Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func achievementRow(_ achievement: StreakAchievement) -> some View {
        let earned = longestStreak >= achievement.days

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    achievementDetails(achievement, earned: earned)
                    Text(earned ? "Earned" : "Locked")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(earned ? Color.accentColor : Color.secondary)
                }
                .padding(.vertical, AppSpacing.xs)
            } else {
                HStack(spacing: AppSpacing.md) {
                    achievementDetails(achievement, earned: earned)
                    Spacer(minLength: AppSpacing.sm)
                    Text(earned ? "Earned" : "Locked")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(earned ? Color.accentColor : Color.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(String(localized: achievement.title)), \(String(localized: "\(achievement.days) day streak")), \(earned ? String(localized: "Earned") : String(localized: "Locked"))"
        )
    }

    private func achievementDetails(_ achievement: StreakAchievement, earned: Bool) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: earned ? "checkmark.circle.fill" : achievement.systemImage)
                .font(.title2)
                .foregroundStyle(earned ? Color.accentColor : Color.secondary)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(achievement.title)
                    .font(.headline)
                Text("\(achievement.days) day streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dayCount(_ count: Int) -> String {
        count == 1 ? String(localized: "1 day") : String(localized: "\(count) days")
    }
}
