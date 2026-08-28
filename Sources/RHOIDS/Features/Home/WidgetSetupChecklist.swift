import SwiftUI

struct WidgetSetupChecklist: View {
    @AppStorage("widgetSetupDismissed") private var dismissed = false
    @Binding private var expanded: Bool
    @State private var steps: [Bool] = [false, false, false, false]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let onExpand: () -> Void

    private var allDone: Bool { steps.allSatisfy { $0 } }

    init(expanded: Binding<Bool>, onExpand: @escaping () -> Void = {}) {
        _expanded = expanded
        self.onExpand = onExpand
    }

    var body: some View {
        if !dismissed {
            VStack(alignment: .leading, spacing: 16) {
                header

                if expanded {
                    VStack(alignment: .leading, spacing: 12) {
                        stepRow(0, "Long press your Home Screen until the apps wiggle")
                        stepRow(1, "Tap the + button in the top corner")
                        stepRow(2, "Search \"RHOIDS\" and add the small widget")
                        stepRow(3, "Tap the widget when you sit down to start your timer instantly")
                    }
                    .padding(.top, 4)
                    .transition(AppMotion.edgeFade(.top, reduceMotion: reduceMotion))

                    if allDone {
                        Button(action: {
                            withAnimation(AppMotion.reveal(reduceMotion: reduceMotion)) { dismissed = true }
                        }) {
                            Text("Done, I've set it up")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .padding(.top, 4)
                        .transition(.opacity)
                    }
                }
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .accessibilityElement(children: .contain)
        }
    }

    private var header: some View {
        Button(action: toggleExpanded) {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.body)
                    .foregroundStyle(.brand)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add the widget to your Home Screen")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("One tap to start. No excuses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Widget setup guide")
        .accessibilityHint(expanded ? "Collapse steps" : "Expand steps")
    }

    private func toggleExpanded() {
        let shouldScrollAfterExpansion = !expanded

        withAnimation(AppMotion.contextChange(reduceMotion: reduceMotion)) {
            expanded.toggle()
        } completion: {
            if shouldScrollAfterExpansion {
                onExpand()
            }
        }
    }

    private func stepRow(_ index: Int, _ text: String) -> some View {
        Button(action: {
            withAnimation(AppMotion.feedback(reduceMotion: reduceMotion)) {
                steps[index].toggle()
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: steps[index] ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(steps[index] ? Color.accentColor : .secondary)
                    .frame(width: 22)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(steps[index] ? .secondary : .primary)
                    .strikethrough(steps[index])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityAddTraits(steps[index] ? .isSelected : [])
        .accessibilityHint(
            "Double-tap to mark as \(steps[index] ? String(localized: "incomplete") : String(localized: "complete"))"
        )
    }
}

#if DEBUG
#Preview {
    WidgetSetupChecklist(expanded: .constant(false))
        .padding()
}
#endif
