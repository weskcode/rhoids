import Foundation

/// Single source of truth for App Group identifiers and UserDefaults keys
/// shared across the main app, widget extension, and Watch widget.
///
/// Every target that reads or writes timer state must use these constants
/// so that a key rename is a one-line change with compile-time coverage.
enum SharedStateKeys {
    static let suiteName = "group.com.wesley.RHOIDS"
    static let timerEndDate = "activeTimerEndDate"
    static let timerIsRunning = "timerIsRunning"
    static let timerPresetName = "activeTimerPresetName"
    static let timerDuration = "activeTimerDuration"
}
