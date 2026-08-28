import Foundation
import WatchKit

/// Maps timer events to semantically appropriate watchOS haptic patterns.
///
/// Respects the user's `hapticsEnabled` preference synced from iPhone.
/// Haptic types follow Apple HIG:
/// - `.start` - activity beginning
/// - `.stop` - activity ending
/// - `.notification` - general alert (timer complete)
/// - `.directionDown` - warning/attention needed
/// - `.click` - discrete selection
enum WatchHaptics {

    private static var isEnabled: Bool {
        UserPreferences.hapticsEnabled
    }

    /// Timer successfully started.
    static func timerStarted() {
        guard isEnabled else { return }
        WKInterfaceDevice.current().play(.start)
    }

    /// Timer completed naturally - primary alert.
    /// Plays notification + stop in sequence for emphasis.
    static func timerCompleted() {
        guard isEnabled else { return }
        Task { @MainActor in
            WKInterfaceDevice.current().play(.notification)
            try? await Task.sleep(for: .milliseconds(600))
            WKInterfaceDevice.current().play(.stop)
            try? await Task.sleep(for: .milliseconds(600))
            WKInterfaceDevice.current().play(.notification)
        }
    }

    /// User cancelled the timer early.
    static func timerCancelled() {
        guard isEnabled else { return }
        WKInterfaceDevice.current().play(.stop)
    }

    /// 30-second interval warning tick.
    static func warningTick() {
        guard isEnabled else { return }
        WKInterfaceDevice.current().play(.directionDown)
    }

    /// Preset row tapped / selection changed.
    static func presetSelected() {
        guard isEnabled else { return }
        WKInterfaceDevice.current().play(.click)
    }

    /// Digital Crown detent (handled by system when `isHapticFeedbackEnabled: true`).
    /// This is here for manual Crown scenarios only.
    static func crownDetent() {
        guard isEnabled else { return }
        WKInterfaceDevice.current().play(.click)
    }

    /// Positive outcome (early stop = good behavior).
    static func positiveOutcome() {
        guard isEnabled else { return }
        WKInterfaceDevice.current().play(.success)
    }
}
