import WidgetKit
import Foundation

struct RHOIDSTimelineProvider: TimelineProvider {
    typealias Entry = RHOIDSEntry

    func placeholder(in context: Context) -> RHOIDSEntry {
        RHOIDSEntry(date: Date(), timerEndDate: nil, presetName: nil, isRunning: false, duration: 0, family: context.family)
    }

    func getSnapshot(in context: Context, completion: @escaping (RHOIDSEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RHOIDSEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: SharedStateKeys.suiteName)
        let endDate = defaults?.object(forKey: SharedStateKeys.timerEndDate) as? Date
        let isRunning = defaults?.bool(forKey: SharedStateKeys.timerIsRunning) ?? false
        let presetName = defaults?.string(forKey: SharedStateKeys.timerPresetName)
        let duration = defaults?.double(forKey: SharedStateKeys.timerDuration) ?? 0
        let now = Date()

        if isRunning, let endDate = endDate, endDate > now {
            // Timer-backed Text and ProgressView instances update themselves
            // between entries, including while the host app is suspended.
            let activeEntry = RHOIDSEntry(
                date: now,
                timerEndDate: endDate,
                presetName: presetName,
                isRunning: true,
                duration: duration,
                family: context.family
            )
            let expiredEntry = RHOIDSEntry(
                date: endDate,
                timerEndDate: nil,
                presetName: nil,
                isRunning: false,
                duration: 0,
                family: context.family
            )
            completion(Timeline(entries: [activeEntry, expiredEntry], policy: .atEnd))
        } else {
            // Stale state cleanup is owned by TimerService in the main app;
            // the provider is read-only and must not write to the App Group.
            let idle = RHOIDSEntry(
                date: now,
                timerEndDate: nil,
                presetName: nil,
                isRunning: false,
                duration: 0,
                family: context.family
            )
            completion(Timeline(entries: [idle], policy: .never))
        }
    }
}
