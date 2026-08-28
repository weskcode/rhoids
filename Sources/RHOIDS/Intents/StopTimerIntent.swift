import AppIntents

struct StopTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop RHOIDS Timer"
    static let description = IntentDescription("Stop the active bathroom timer.")

    func perform() async throws -> some IntentResult {
        if let services = await AppServices.shared {
            await services.timerService.stop()
        } else {
            let sharedState = SharedStateService()
            let notifications = NotificationService()
            let liveActivity = LiveActivityService()
            let alarmKit = AlarmKitService()
            await sharedState.clearTimer()
            await notifications.cancelAll()
            await liveActivity.endAllStaleActivities()
            // AlarmKit's active alarm ID is persisted in the shared app
            // group, so a freshly-constructed service in this process can
            // still find and cancel the alarm the main app scheduled.
            await alarmKit.cancelActive()
        }
        return .result()
    }
}
