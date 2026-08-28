import UserNotifications
import os.log

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "Notifications")

extension UNNotificationRequest: @retroactive @unchecked Sendable {}
extension UNUserNotificationCenter: @retroactive @unchecked Sendable {}

protocol NotificationSchedulingCenter: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String]) async
}

extension UNUserNotificationCenter: NotificationSchedulingCenter {
    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// Handles all local notification scheduling for the timer.
///
/// Architecture notes:
/// - Two `UNNotificationRequest`s are scheduled at timer start: a
///   30‑second warning (T‑30) and the alarm (T). iOS delivers them
///   even if the app is suspended or force‑quit.
/// - Additional "boundary beep" notifications fire every 30 seconds
///   while the timer runs, providing audible + banner alerts when
///   the app is backgrounded. When the app is in the foreground the
///   `NotificationDelegate` suppresses them (the in‑app beep handles it).
/// - Identifiers are stable so cancelling on early stop works.
/// - We deliberately do NOT use `.criticalAlert` - it requires a
///   special entitlement from Apple (`com.apple.developer.usernotifications.critical-alerts`).
///   `.timeSensitive` is the right level for a personal timer.
actor NotificationService {
    static let dailyReminderID = "rhoids.daily.reminder"

    private let center: any NotificationSchedulingCenter
    private let completeID = "rhoids.timer.complete"
    private let warningID = "rhoids.timer.warning"
    private let startReminderID = "rhoids.timer.startReminder"
    private let cooldownCompleteID = "rhoids.focusLock.cooldownComplete"

    /// Prefix for the 30-second boundary beep notifications.
    /// Full identifier is `rhoids.timer.beep.150`, `.beep.120`, etc.
    static let beepIDPrefix = "rhoids.timer.beep."

    /// Tracks scheduled beep IDs so we can cancel them precisely.
    private var scheduledBeepIDs: [String] = []
    private var timerSchedulingGeneration: UInt = 0
    private var beepSchedulingGeneration: UInt = 0

    private enum SchedulingToken: Sendable {
        case timer(UInt)
        case beep(UInt)
    }

    init(center: any NotificationSchedulingCenter = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// Apple recommends asking once, on first meaningful interaction.
    /// Calling repeatedly is safe but only the first call shows a prompt.
    /// Returns `true` if the user has authorized alerts.
    ///
    /// Note: `.timeSensitive` was deprecated as a request option in iOS 15.
    /// Time‑sensitive delivery is controlled by setting
    /// `interruptionLevel = .timeSensitive` on each notification's content
    /// (we do - see `scheduleAlarm` / `scheduleWarning`). The user can
    /// toggle Time Sensitive notifications per‑app in
    /// Settings → Notifications → RHOIDS → Time Sensitive Notifications.
    @discardableResult
    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(
            options: [.alert, .sound, .badge]
        )
        log.debug("requestAuthorization - granted=\(granted)")
        return granted
    }

    /// Reads the current authorization status without prompting.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    func scheduleDailyReminder(hour: Int, minute: Int) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Keep your streak going")
        content.body = String(localized: "Open RHOIDS for today's check-in.")
        content.sound = .default
        content.threadIdentifier = "rhoids.daily"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyReminderID,
            content: content,
            trigger: trigger
        )
        // A request with the same stable identifier replaces the previous one.
        // Do not remove the existing request first: if scheduling fails, the
        // user's last valid reminder remains in place.
        return await add(request, context: "daily reminder")
    }

    func cancelDailyReminder() async {
        await center.removePendingRequests(withIdentifiers: [Self.dailyReminderID])
    }

    /// Schedules the warning (T‑30) and optionally the completion alarm (T).
    /// Cancels any previously‑scheduled pair first so rapid restarts don't
    /// queue stale alerts.
    /// - Parameter includeCompletion: when AlarmKit handles the full-screen
    ///   alarm at expiry, pass `false` so we don't double-alert the user.
    func schedule(endDate: Date,
                  presetName: String,
                  warningEnabled: Bool,
                  alarmSound: AlarmSound,
                  warningSound: AlarmSound,
                  includeCompletion: Bool = true,
                  messagingMode: FocusLockMode? = nil,
                  cooldownMinutes: Int = 5) async {
        log.debug("schedule - endDate=\(endDate), warning=\(warningEnabled), includeCompletion=\(includeCompletion)")
        timerSchedulingGeneration &+= 1
        beepSchedulingGeneration &+= 1
        let token = SchedulingToken.timer(timerSchedulingGeneration)
        await removeTimerRequests(includeCooldown: true)
        guard isCurrent(token) else { return }

        if includeCompletion {
            await scheduleAlarm(at: endDate, presetName: presetName, sound: alarmSound,
                                messagingMode: messagingMode, cooldownMinutes: cooldownMinutes,
                                token: token)
            guard isCurrent(token) else { return }
        }
        if warningEnabled {
            await scheduleWarning(at: endDate.addingTimeInterval(-30),
                                  sound: warningSound,
                                  token: token)
            guard isCurrent(token) else { return }
        }
        if messagingMode == .limitedScrolling {
            await scheduleCooldownComplete(
                at: endDate.addingTimeInterval(TimeInterval(cooldownMinutes * 60)),
                token: token
            )
        }
    }

    /// Fires a one-off reminder shortly after the timer starts. Only used by
    /// Path 1 (Phone-Free) - Limited Scrolling has nothing to remind at
    /// start, since using allowed apps is the point. Not covered by
    /// `schedule()`'s internal `cancelAll()` (it's scheduled separately,
    /// right after), but is cancelled by the top-level `cancelAll()` below.
    func scheduleStartReminder(mode: FocusLockMode) async {
        guard let copy = mode.startReminder else { return }
        let token = SchedulingToken.timer(timerSchedulingGeneration)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "rhoids.timer"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: startReminderID, content: content, trigger: trigger)
        await add(request, context: "start reminder notification", token: token)
    }

    /// Schedules drop-down banner notifications at every 30-second boundary
    /// during the timer. These fire in the background to keep the user
    /// informed; the in-app beep handles foreground alerts (the
    /// `NotificationDelegate` suppresses these when the app is active).
    func scheduleBeepNotifications(
        duration: TimeInterval,
        endDate: Date,
        sound: AlarmSound
    ) async {
        beepSchedulingGeneration &+= 1
        let token = SchedulingToken.beep(beepSchedulingGeneration)

        // Cancel any leftover beeps from a previous timer
        await cancelBeepNotifications()
        guard isCurrent(token) else { return }

        // Calculate 30-second boundaries counting down from duration.
        // For a 180s timer: beeps at 150s, 120s, 90s, 60s remaining
        // (the final 30s is handled by the existing warning notification).
        var secondsFromStart: TimeInterval = 30
        var ids: [String] = []

        while secondsFromStart < duration - 30 {
            let remaining = duration - secondsFromStart
            let fireDate = endDate.addingTimeInterval(-remaining)
            let interval = fireDate.timeIntervalSinceNow

            guard interval > 1 else {
                secondsFromStart += 30
                continue
            }

            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            let timeString = minutes > 0
                ? (seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes) min")
                : "\(seconds)s"

            let content = UNMutableNotificationContent()
            content.title = String(localized: "⏱ \(timeString) remaining")
            content.body = TimerQuip.randomBeep().body
            content.sound = sound.notificationSound()
            content.interruptionLevel = .timeSensitive
            content.categoryIdentifier = "TIMER_BEEP"
            content.threadIdentifier = "rhoids.timer"

            let id = "\(Self.beepIDPrefix)\(Int(remaining))"
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: interval,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: trigger
            )
            let scheduled = await add(
                request,
                context: "beep notification \(id)",
                token: token
            )
            guard isCurrent(token) else { return }
            if scheduled {
                ids.append(id)
            }

            secondsFromStart += 30
        }

        scheduledBeepIDs = ids
        log.debug("scheduled \(ids.count) beep notification(s)")
    }

    /// Cancel timer-related requests. The independently controlled daily
    /// reminder is intentionally preserved.
    func cancelAll() async {
        timerSchedulingGeneration &+= 1
        beepSchedulingGeneration &+= 1
        await removeTimerRequests(includeCooldown: true)
    }

    /// Natural timer completion should stand down timer-active alerts while
    /// preserving the separately scheduled cooldown-complete encouragement.
    func cancelTimerAlertsPreservingCooldown() async {
        timerSchedulingGeneration &+= 1
        beepSchedulingGeneration &+= 1
        await removeTimerRequests(includeCooldown: false)
    }

    // MARK: - Private

    private func cancelBeepNotifications() async {
        guard !scheduledBeepIDs.isEmpty else { return }
        await center.removePendingRequests(withIdentifiers: scheduledBeepIDs)
        scheduledBeepIDs = []
    }

    private func removeTimerRequests(includeCooldown: Bool) async {
        var allIDs = [completeID, warningID, startReminderID]
        if includeCooldown {
            allIDs.append(cooldownCompleteID)
        }
        allIDs.append(contentsOf: scheduledBeepIDs)
        await center.removePendingRequests(withIdentifiers: allIDs)
        scheduledBeepIDs = []
    }

    private func scheduleAlarm(at date: Date,
                               presetName: String,
                               sound: AlarmSound,
                               messagingMode: FocusLockMode? = nil,
                               cooldownMinutes: Int = 5,
                               token: SchedulingToken) async {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let copy = messagingMode?.completionCopy(cooldownMinutes: cooldownMinutes)
        let content = UNMutableNotificationContent()
        content.title = copy?.title ?? String(localized: "Time's up!")
        content.body = copy?.body ?? String(localized: "Stand up and walk away. Not done? That's fine. Come back later.")
        content.subtitle = presetName
        content.sound = sound.notificationSound()
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0
        content.categoryIdentifier = "TIMER_COMPLETE"
        content.threadIdentifier = "rhoids.timer"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: completeID, content: content, trigger: trigger)
        await add(request, context: "completion notification", token: token)
    }

    private func scheduleWarning(
        at date: Date,
        sound: AlarmSound,
        token: SchedulingToken
    ) async {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }   // nothing to do for short timers

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Almost done. Don't rush!")
        content.body = TimerQuip.randomWarning().body
        content.sound = sound.notificationSound()
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "TIMER_WARNING"
        content.threadIdentifier = "rhoids.timer"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: warningID, content: content, trigger: trigger)
        await add(request, context: "warning notification", token: token)
    }

    private func scheduleCooldownComplete(
        at date: Date,
        token: SchedulingToken
    ) async {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Cooldown complete")
        content.body = String(localized: "Nice work - your selected apps are available again. Take a moment to recognize the break you gave yourself today.")
        content.sound = .default
        content.interruptionLevel = .active
        content.threadIdentifier = "rhoids.focusLock"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: cooldownCompleteID,
            content: content,
            trigger: trigger
        )
        await add(request, context: "cooldown completion notification", token: token)
    }

    @discardableResult
    private func add(
        _ request: UNNotificationRequest,
        context: String,
        token: SchedulingToken? = nil
    ) async -> Bool {
        do {
            try await center.add(request)
            if let token, !isCurrent(token) {
                await center.removePendingRequests(withIdentifiers: [request.identifier])
                return false
            }
            return true
        } catch {
            log.error("failed to schedule \(context): \(error)")
            return false
        }
    }

    private func isCurrent(_ token: SchedulingToken) -> Bool {
        switch token {
        case .timer(let generation):
            generation == timerSchedulingGeneration
        case .beep(let generation):
            generation == beepSchedulingGeneration
        }
    }
}
