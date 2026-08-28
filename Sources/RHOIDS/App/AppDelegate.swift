import UIKit
import UserNotifications
import os.log

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "Notifications")

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared
        registerCategories(center: center)
        return true
    }

    private func registerCategories(center: UNUserNotificationCenter) {
        // Optional: action buttons on the alarm.
        let snooze = UNNotificationAction(
            identifier: "TIMER_SNOOZE",
            title: "+1 min",
            options: []
        )
        let dismiss = UNNotificationAction(
            identifier: "TIMER_DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        let alarmCategory = UNNotificationCategory(
            identifier: "TIMER_COMPLETE",
            actions: [snooze, dismiss],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let warningCategory = UNNotificationCategory(
            identifier: "TIMER_WARNING",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let beepCategory = UNNotificationCategory(
            identifier: "TIMER_BEEP",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([alarmCategory, warningCategory, beepCategory])
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationDelegate()
    static let timerCompleteCategoryID = "TIMER_COMPLETE"
    static let timerDismissActionID = "TIMER_DISMISS"
    static let timerSnoozeActionID = "TIMER_SNOOZE"

    /// When the app is foregrounded, our in-app UI handles timer alerts -     /// the 30-second warning beeps fire from TimerService and the completion
    /// alarm loops from AlarmPlayer. Suppress the OS notification's banner +
    /// sound for those identifiers so we don't double up audio.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let id = notification.request.identifier
        let isTimerNotification =
            id == "rhoids.timer.complete" ||
            id == "rhoids.timer.warning" ||
            id.hasPrefix(NotificationService.beepIDPrefix)

        if isTimerNotification {
            // App is in foreground - the in-app beep/alarm handles audio.
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .list])
    }

    /// Action button taps from the alarm notification banner.
    /// - "TIMER_DISMISS" - clears shared state, kills the Live Activity, stops any in-app alarm loop
    /// - `UNNotificationDismissActionIdentifier` - the banner/list close control for the completion alarm
    /// - "TIMER_SNOOZE" - starts a fresh 60-second snooze timer
    /// - default tap - opens the app; HomeView's pending-timer check handles the rest
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionID = Self.normalizedActionID(
            actionIdentifier: response.actionIdentifier,
            categoryIdentifier: response.notification.request.content.categoryIdentifier
        )
        // Acknowledge receipt synchronously so iOS can release the
        // dispatch context; the actual side effects run on the main actor.
        // Avoids the Swift 6 strict-concurrency violation of sending a
        // non-Sendable closure across an isolation boundary.
        completionHandler()
        Task { @MainActor in
            await NotificationDelegate.handleAction(actionID)
        }
    }

    @MainActor
    private static func handleAction(_ actionID: String) async {
        guard let services = AppServices.shared else { return }

        switch actionID {
        case Self.timerDismissActionID:
            log.debug("TIMER_DISMISS action")
            await services.timerService.stop()
            services.sharedStateService.clearTimer()
            await services.liveActivityService.end()
            await services.alarmPlayer.stopAlarm()
            await services.notificationService.cancelAll()
            await services.alarmKitService.cancelActive()

        case Self.timerSnoozeActionID:
            log.debug("TIMER_SNOOZE action (+60s)")
            await services.alarmPlayer.stopAlarm()
            let snoozePreset = PresetTimer(
                id: UUID(uuidString: "A1B2C3D4-9999-0000-0000-000000000099") ?? UUID(),
                name: "Snooze",
                duration: 60,
                subtitle: "Extra time",
                systemImage: "clock.arrow.circlepath",
                isRecommended: false
            )
            let prefs = TimerService.TimerPreferences.current(warningEnabled: false)
            await services.timerService.start(duration: 60, preset: snoozePreset, preferences: prefs)

        default:
            // Default banner tap - the app is launching; HomeView's
            // scenePhase check will detect the pending timer and route
            // to TimerRunningView automatically.
            break
        }
    }

    static func normalizedActionID(actionIdentifier: String, categoryIdentifier: String) -> String {
        if actionIdentifier == UNNotificationDismissActionIdentifier,
           categoryIdentifier == timerCompleteCategoryID {
            return timerDismissActionID
        }
        return actionIdentifier
    }
}
