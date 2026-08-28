import SwiftUI

/// A reusable empty state built on `ContentUnavailableView` (the HIG-standard
/// component) with an optional call-to-action button. Centralizes empty-state
/// styling so every "nothing here yet" screen reads the same.
///
/// The icon gets a gentle one-shot bounce on appear (respecting Reduce Motion)
/// so the screen feels alive rather than blank.
struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.brand)
                    .symbolEffect(.bounce, value: appeared)
            }
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        }
        .task {
            guard !reduceMotion else { return }
            appeared = true
        }
    }
}

#if DEBUG
#Preview {
    EmptyStateView(
        icon: "timer",
        title: "No sessions yet",
        message: "Start your first timer to see your history here."
    )
}
#endif
