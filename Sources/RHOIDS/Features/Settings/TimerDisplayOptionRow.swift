import SwiftUI

struct TimerDisplayOptionRow: View {
    let style: TimerStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.displayName)
                            .font(.headline)

                        Text(style.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.headline)
                            .foregroundStyle(.tint)
                            .transition(.opacity)
                    }
                }

                TimerStylePreview(style: style)
                    .frame(maxWidth: .infinity)
                    .frame(height: 156)
                    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(style.displayName), \(style.description)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Shows the countdown using this style.")
    }
}

#if DEBUG
    #Preview {
        List {
            TimerDisplayOptionRow(style: .flip, isSelected: true, action: {})
            TimerDisplayOptionRow(style: .ring, isSelected: false, action: {})
        }
    }
#endif
