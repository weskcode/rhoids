import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \TimerSession.startedAt, order: .reverse) private var sessions: [TimerSession]
    let dailyUseTracker: DailyUseTracker

    private var weeklyStats: WeeklySessionStats {
        WeeklySessionStats.calculate(sessions: sessions)
    }

    var body: some View {
        NavigationStack {
            List {
                streakSection

                if sessions.isEmpty {
                    Section("Recent Sessions") {
                        ContentUnavailableView(
                            "No sessions yet",
                            systemImage: "timer",
                            description: Text("Start your first timer to see your history here.")
                        )
                    }
                } else {
                    weeklyStatsSection
                    recentSessionsSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
        }
    }

    private var streakSection: some View {
        Section {
            NavigationLink {
                StreakAchievementsView(
                    currentStreak: dailyUseTracker.currentStreak,
                    longestStreak: dailyUseTracker.longestStreak
                )
            } label: {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Days Used Streak")
                            .font(.headline)
                        Label(dayCount(dailyUseTracker.currentStreak), systemImage: "flame.fill")
                            .font(.title2.bold())
                            .foregroundStyle(Color.accentColor)
                        Text("Keep showing up each day")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, AppSpacing.xs)
                } else {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("Days Used Streak")
                                .font(.headline)
                            Text("Keep showing up each day")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: AppSpacing.sm)

                        Text("\(dailyUseTracker.currentStreak)")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Days used streak, \(dayCount(dailyUseTracker.currentStreak))")
            .accessibilityHint("Shows streak achievements")
        }
    }

    private func dayCount(_ count: Int) -> String {
        count == 1 ? String(localized: "1 day") : String(localized: "\(count) days")
    }

    // MARK: - Weekly Stats

    private var weeklyStatsSection: some View {
        let stats = weeklyStats
        return Section("This week") {
            HStack(spacing: AppSpacing.md) {
                StatCard(
                    icon: "calendar",
                    value: "\(stats.count)",
                    label: "Sessions"
                )
                StatCard(
                    icon: "clock",
                    value: DurationFormatter.formatted(stats.averageDuration),
                    label: "Avg. time"
                )
            }
            .listRowInsets(EdgeInsets(
                top: AppSpacing.xs,
                leading: AppSpacing.lg,
                bottom: AppSpacing.md,
                trailing: AppSpacing.lg
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        Section("Recent Sessions") {
            ForEach(sessions) { session in
                sessionRow(session)
            }
        }
    }

    private func sessionRow(_ session: TimerSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: session.wasInterrupted ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(session.wasInterrupted ? Color.orange : Color.accentColor)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.presetName ?? "Custom")
                    .font(.body)
                Text(formattedSessionDate(session.startedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(DurationFormatter.formatted(session.actualDuration))
                .font(.callout.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: session))
    }

    private func formattedSessionDate(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) {
            return String(localized: "Today, \(time)")
        } else if Calendar.current.isDateInYesterday(date) {
            return String(localized: "Yesterday, \(time)")
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day()) + ", \(time)"
        }
    }

    private func accessibilityLabel(for session: TimerSession) -> String {
        let preset = session.presetName ?? String(localized: "Custom")
        let status = session.wasInterrupted ? String(localized: "stopped early") : String(localized: "completed")
        let duration = DurationFormatter.formatted(session.actualDuration)
        let when = formattedSessionDate(session.startedAt)
        return "\(preset) timer, \(status), \(duration), \(when)"
    }
}

#if DEBUG
#Preview("Empty") {
    HistoryView(dailyUseTracker: DailyUseTracker())
        .modelContainer(for: TimerSession.self, inMemory: true)
}
#endif
