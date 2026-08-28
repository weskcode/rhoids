import ActivityKit
import Foundation
import os.log

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "LiveActivity")

actor LiveActivityService {
    private var currentActivityID: String?

    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(preset: PresetTimer, duration: TimeInterval, endDate: Date) async throws {
        let authInfo = ActivityAuthorizationInfo()
        log.info("start() - areActivitiesEnabled=\(authInfo.areActivitiesEnabled), frequentPushesEnabled=\(authInfo.frequentPushesEnabled), preset=\(preset.name), duration=\(duration)s")

        let existingActivities = Activity<RHOIDSActivityAttributes>.activities
        log.info("existing activities count: \(existingActivities.count)")
        for existing in existingActivities {
            log.info("  existing: id=\(existing.id), state=\(String(describing: existing.activityState))")
        }

        guard authInfo.areActivitiesEnabled else {
            log.warning("ACTIVITIES NOT ENABLED - user must enable in Settings > RHOIDS > Live Activities")
            throw LiveActivityError.activitiesDisabled
        }

        for existing in existingActivities {
            log.info("ending existing activity \(existing.id)")
            await existing.end(nil, dismissalPolicy: .immediate)
        }
        currentActivityID = nil

        let attributes = RHOIDSActivityAttributes(
            plannedDuration: duration,
            presetIcon: preset.systemImage
        )
        let content = ActivityContent(
            state: RHOIDSActivityAttributes.ContentState(
                endDate: endDate,
                presetName: preset.name
            ),
            staleDate: endDate
        )

        log.info("requesting activity - plannedDuration=\(duration), endDate=\(endDate), presetName=\(preset.name)")
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivityID = activity.id
            log.info("✅ started successfully - id=\(activity.id), activityState=\(String(describing: activity.activityState))")

            let activeCount = Activity<RHOIDSActivityAttributes>.activities.count
            log.info("active activities after start: \(activeCount)")
        } catch {
            log.error("❌ failed to start: \(error)")
            throw error
        }
    }

    func update(endDate: Date) async {
        guard let id = currentActivityID,
              let activity = Activity<RHOIDSActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        let presetName = activity.content.state.presetName
        let content = ActivityContent(
            state: RHOIDSActivityAttributes.ContentState(
                endDate: endDate,
                presetName: presetName
            ),
            staleDate: endDate
        )
        await activity.update(content)
    }

    func markComplete() async {
        log.info("markComplete() - currentActivityID=\(self.currentActivityID ?? "nil")")
        if let id = currentActivityID,
           let activity = Activity<RHOIDSActivityAttributes>.activities.first(where: { $0.id == id }) {
            let presetName = activity.content.state.presetName
            let content = ActivityContent(
                state: RHOIDSActivityAttributes.ContentState(
                    endDate: Date(),
                    presetName: presetName
                ),
                staleDate: nil
            )
            // End with a delayed dismissal - the "Time's up!" state stays
            // visible for 5 minutes so the user can see it on the Lock
            // Screen, then auto-removes. If the user opens the app and
            // taps Dismiss sooner, `dismiss()` overrides this with
            // `.immediate`.
            await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(300)))
            log.info("ended with 5-minute delayed dismissal")
        }
    }

    func dismiss() async {
        log.info("dismiss() - currentActivityID=\(self.currentActivityID ?? "nil")")
        if let id = currentActivityID,
           let activity = Activity<RHOIDSActivityAttributes>.activities.first(where: { $0.id == id }) {
            let presetName = activity.content.state.presetName
            let content = ActivityContent(
                state: RHOIDSActivityAttributes.ContentState(
                    endDate: Date(),
                    presetName: presetName
                ),
                staleDate: nil
            )
            await activity.end(content, dismissalPolicy: .immediate)
        } else {
            for activity in Activity<RHOIDSActivityAttributes>.activities {
                log.info("ending orphan activity \(activity.id)")
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivityID = nil
    }

    func end() async {
        log.info("end() - immediate dismiss")
        await dismiss()
    }

    func endAllStaleActivities() async {
        for activity in Activity<RHOIDSActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivityID = nil
    }
}

enum LiveActivityError: LocalizedError {
    case activitiesDisabled

    var errorDescription: String? {
        switch self {
        case .activitiesDisabled:
            "Live Activities are disabled. Enable them in Settings > RHOIDS > Live Activities."
        }
    }
}
