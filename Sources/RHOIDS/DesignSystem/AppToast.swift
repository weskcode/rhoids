import SwiftUI

/// A lightweight, transient confirmation ("Focus Lock turned off", etc.).
/// Present one by setting an `@State var toast: AppToast?` and attaching
/// `.toast($toast)` to a container view. It auto-dismisses, respects Reduce
/// Motion, and announces itself to VoiceOver.
struct AppToast: Equatable, Identifiable {
    let id = UUID()
    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var tint: Color = .brand

    static func == (lhs: AppToast, rhs: AppToast) -> Bool { lhs.id == rhs.id }
}

extension View {
    /// Overlays a transient toast on this view.
    /// - Parameter edge: which edge the toast anchors to (`.bottom` by default;
    ///   use `.top` on screens with a bottom call-to-action).
    func toast(_ toast: Binding<AppToast?>, edge: VerticalEdge = .bottom) -> some View {
        modifier(ToastModifier(toast: toast, edge: edge))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var toast: AppToast?
    let edge: VerticalEdge
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: edge == .top ? .top : .bottom) {
                if let toast {
                    ToastView(toast: toast)
                        .padding(.horizontal, AppSpacing.xxl)
                        .padding(edge == .top ? .top : .bottom, AppSpacing.sm)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: edge == .top ? .top : .bottom).combined(with: .opacity)
                        )
                        // Never intercept touches on the underlying UI.
                        .allowsHitTesting(false)
                        .task(id: toast.id) {
                            AccessibilityNotification.Announcement(toast.message).post()
                            try? await Task.sleep(for: .seconds(2.2))
                            self.toast = nil
                        }
                }
            }
            .animation(AppMotion.reveal(reduceMotion: reduceMotion), value: toast)
    }
}

private struct ToastView: View {
    let toast: AppToast

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: toast.systemImage)
                .foregroundStyle(toast.tint)
                .symbolRenderingMode(.hierarchical)
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var toast: AppToast? = AppToast(message: "Focus Lock turned off")
    Color(.systemBackground)
        .toast($toast)
}
#endif
