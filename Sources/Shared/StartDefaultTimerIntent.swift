import AppIntents
import Foundation
import WidgetKit

/// Starts the user's default RHOIDS timer from the home screen widget.
/// Writes the timer state into the App Group and opens the host app,
/// which adopts the running timer and handles alarms, notifications,
/// and the Live Activity.
struct StartDefaultTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Default RHOIDS Timer"
    static let description = IntentDescription("Starts the default RHOIDS bathroom timer from app settings.")

    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let preset = PresetPreferences.defaultPreset
        let duration = preset.duration > 0 ? preset.duration : 180
        let endDate = Date().addingTimeInterval(duration)

        let defaults = UserDefaults(suiteName: SharedStateKeys.suiteName)
        defaults?.set(endDate, forKey: SharedStateKeys.timerEndDate)
        defaults?.set(true, forKey: SharedStateKeys.timerIsRunning)
        defaults?.set(preset.name, forKey: SharedStateKeys.timerPresetName)
        defaults?.set(duration, forKey: SharedStateKeys.timerDuration)
        // Intentionally no WidgetCenter.shared.reloadAllTimelines() here - calling it
        // from inside perform() causes a deadlock in the widget extension process.
        // The app reloads all timelines via SharedStateService.setTimer() after adoption.
        return .result()
    }
}
