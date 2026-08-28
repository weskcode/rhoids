import SwiftUI

struct TimerDisplayPickerView: View {
    @AppStorage(UserPreferences.timerStyleKey) private var timerStyle: TimerStyle = .card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        List {
            Section {
                ForEach(TimerStyle.allCases) { style in
                    TimerDisplayOptionRow(
                        style: style,
                        isSelected: timerStyle == style,
                        action: { select(style) }
                    )
                }
            } header: {
                Text("Choose how the countdown looks while a timer is running. Your choice is saved automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textCase(nil)
            }
        }
        .navigationTitle("Timer Display")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ style: TimerStyle) {
        withAnimation(AppMotion.optionSelection(reduceMotion: reduceMotion)) {
            timerStyle = style
        }
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            TimerDisplayPickerView()
        }
    }
#endif
