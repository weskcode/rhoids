import SwiftUI

/// A reusable button style that gives a subtle "press-in" response - a slight
/// scale-down while held - for custom (non-system-chrome) buttons like list
/// rows and cards. Respects Reduce Motion and uses the app's `AppMotion`
/// feedback curve so it feels consistent with the rest of the app.
///
/// Behaves like `.plain` (no tint/chrome) but adds tactile feedback. Apply the
/// pressed background *inside* the label so the whole surface scales together.
struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.98

    func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration, pressedScale: pressedScale)
    }

    private struct PressableBody: View {
        let configuration: ButtonStyleConfiguration
        let pressedScale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : pressedScale)
                .animation(AppMotion.feedback(reduceMotion: reduceMotion), value: configuration.isPressed)
                .contentShape(Rectangle())
        }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// A `.plain`-like style with a subtle press-in scale. See `PressableButtonStyle`.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
