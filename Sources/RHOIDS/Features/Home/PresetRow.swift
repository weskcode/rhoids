import SwiftUI

struct PresetRow: View {
    let preset: PresetTimer
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: preset.systemImage)
                    .font(.body)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(preset.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if preset.duration > 0 {
                    Text(preset.formattedDuration)
                        .font(.title3.monospacedDigit().weight(.medium))
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                }

                selectionIndicator
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(Color.accentColor.opacity(isSelected ? 0.08 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(AppMotion.optionSelection(reduceMotion: reduceMotion), value: isSelected)
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected ? Color.accentColor : Color(.tertiaryLabel),
                    lineWidth: isSelected ? 2 : 1.5
                )

            Circle()
                .fill(Color.accentColor)
                .scaleEffect(isSelected ? 1 : 0.2)
                .opacity(isSelected ? 1 : 0)

            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .scaleEffect(isSelected && !reduceMotion ? 1 : 0.7)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: 24, height: 24)
    }
}

#if DEBUG
#Preview("Unselected") {
    PresetRow(preset: .recommended, isSelected: false, action: {})
        .padding()
}

#Preview("Selected") {
    PresetRow(preset: .recommended, isSelected: true, action: {})
        .padding()
}

#Preview("All Presets") {
    VStack(spacing: 0) {
        ForEach(PresetTimer.all) { preset in
            PresetRow(
                preset: preset,
                isSelected: preset.isRecommended,
                action: {}
            )
        }
    }
    .padding()
}
#endif
