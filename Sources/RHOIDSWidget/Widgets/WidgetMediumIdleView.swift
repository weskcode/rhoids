import SwiftUI
import WidgetKit

struct WidgetMediumIdleView: View {
    var isAccented = false

    var body: some View {
        Button(intent: StartDefaultTimerIntent()) {
            HStack(spacing: 14) {
                WidgetAppIcon(size: 48, isAccented: isAccented)

                VStack(alignment: .leading, spacing: 4) {
                    Text("RHOIDS")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("Tap to start your timer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start default RHOIDS timer")
        .accessibilityHint("Opens RHOIDS and starts your configured default timer.")
    }
}
