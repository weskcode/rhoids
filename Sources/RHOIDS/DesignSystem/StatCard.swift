import SwiftUI

/// A compact stat tile: brand-tinted icon, a prominent value, and a caption
/// label. Used for the History weekly summary. Reads as a native iOS stat
/// tile (Fitness/Health style) - a tasteful summary, deliberately *not* a
/// gamified dashboard (no goals, streaks, or charts), in keeping with the
/// app's "one job" identity.
struct StatCard: View {
    let icon: String
    /// The runtime value (a number or formatted duration) - not localized.
    let value: String
    /// The caption, localized via the app's string catalog.
    let label: LocalizedStringKey
    var tint: Color = .brand

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text(label)), \(value)"))
    }
}

#if DEBUG
#Preview {
    HStack(spacing: AppSpacing.md) {
        StatCard(icon: "calendar", value: "4", label: "This week")
        StatCard(icon: "clock", value: "3:12", label: "Average")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
#endif
