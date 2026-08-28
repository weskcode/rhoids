import Foundation
import WidgetKit

/// Manages timer state in the App Group so the main app, widget, and
/// Watch extension can all read/write the same active timer.
///
/// Runs on `@MainActor` because:
/// - `WidgetCenter.shared.reloadAllTimelines()` requires the main thread.
/// - `UserDefaults.set()` posts `didChangeNotification` synchronously on
///    the calling thread. `PhoneConnectivityService` (also `@MainActor`)
///    observes that notification, so the write must happen on main to
///    avoid a `dispatch_assert_queue_fail` crash.
@MainActor
final class SharedStateService {
    private let suiteName: String

    nonisolated init(suiteName: String = SharedStateKeys.suiteName) {
        self.suiteName = suiteName
    }

    private let timerEndDateKey = SharedStateKeys.timerEndDate
    private let timerIsRunningKey = SharedStateKeys.timerIsRunning
    private let presetNameKey = SharedStateKeys.timerPresetName
    private let timerDurationKey = SharedStateKeys.timerDuration

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    func setTimer(endDate: Date, presetName: String?, duration: TimeInterval) {
        defaults?.set(endDate, forKey: timerEndDateKey)
        defaults?.set(true, forKey: timerIsRunningKey)
        defaults?.set(presetName, forKey: presetNameKey)
        defaults?.set(duration, forKey: timerDurationKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func clearTimer() {
        defaults?.removeObject(forKey: timerEndDateKey)
        defaults?.set(false, forKey: timerIsRunningKey)
        defaults?.removeObject(forKey: presetNameKey)
        defaults?.removeObject(forKey: timerDurationKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    nonisolated func getTimerState() -> (endDate: Date?, isRunning: Bool, presetName: String?, duration: TimeInterval) {
        let defaults = UserDefaults(suiteName: suiteName)
        let endDate = defaults?.object(forKey: timerEndDateKey) as? Date
        let isRunning = defaults?.bool(forKey: timerIsRunningKey) ?? false
        let presetName = defaults?.string(forKey: presetNameKey)
        let duration = defaults?.double(forKey: timerDurationKey) ?? 0
        return (endDate, isRunning, presetName, duration)
    }
}
