import Testing
import Foundation
import UserNotifications
@testable import RHOIDS

actor TestNotificationSchedulingCenter: NotificationSchedulingCenter {
    enum TestError: Error {
        case schedulingFailed
    }

    private var requests: [String: UNNotificationRequest] = [:]
    private var shouldFailToAdd = false
    private var beforeNextAddition: (@Sendable () async -> Void)?

    func add(_ request: UNNotificationRequest) async throws {
        guard !shouldFailToAdd else { throw TestError.schedulingFailed }
        if let hook = beforeNextAddition {
            beforeNextAddition = nil
            await hook()
        }
        requests[request.identifier] = request
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        for identifier in identifiers {
            requests[identifier] = nil
        }
    }

    func pendingNotificationRequests() -> [UNNotificationRequest] {
        Array(requests.values)
    }

    func failFutureAdditions() {
        shouldFailToAdd = true
    }

    func runBeforeNextAddition(_ operation: @escaping @Sendable () async -> Void) {
        beforeNextAddition = operation
    }
}

struct NotificationSchedulingTests {
    private func pending(
        matching id: String,
        in center: TestNotificationSchedulingCenter
    ) async -> UNNotificationRequest? {
        await center.pendingNotificationRequests().first { $0.identifier == id }
    }

    private func pending(in center: TestNotificationSchedulingCenter) async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    private func withCleanNotificationCenter(
        _ operation: (NotificationService, TestNotificationSchedulingCenter) async throws -> Void
    ) async rethrows {
        let center = TestNotificationSchedulingCenter()
        let sut = NotificationService(center: center)
        try await operation(sut, center)
    }

    // MARK: - Identifier Stability

    @Test func `Completion identifier is stable`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            let req = await pending(matching: "rhoids.timer.complete", in: center)
            #expect(req != nil, "Completion notification must use the stable ID 'rhoids.timer.complete'")
        }
    }

    @Test func `Warning identifier is stable`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: false
            )

            let req = await pending(matching: "rhoids.timer.warning", in: center)
            #expect(req != nil, "Warning notification must use the stable ID 'rhoids.timer.warning'")
        }
    }

    @Test func `Limited Scrolling schedules cooldown completion encouragement`() async throws {
        try await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: false,
                messagingMode: .limitedScrolling,
                cooldownMinutes: 5
            )

            let request = try #require(
                await pending(matching: "rhoids.focusLock.cooldownComplete", in: center)
            )
            #expect(request.content.title == "Cooldown complete")
            #expect(request.content.body.contains("available again"))
            let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
            #expect(abs(trigger.timeInterval - 420) < 2)
        }
    }

    @Test func `Phone-Free mode does not schedule cooldown completion encouragement`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: false,
                messagingMode: .phoneFree,
                cooldownMinutes: 5
            )

            let request = await pending(matching: "rhoids.focusLock.cooldownComplete", in: center)
            #expect(request == nil)
        }
    }

    @Test func `CancelAll removes cooldown completion encouragement`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: false,
                messagingMode: .limitedScrolling,
                cooldownMinutes: 5
            )

            await sut.cancelAll()

            let request = await pending(matching: "rhoids.focusLock.cooldownComplete", in: center)
            #expect(request == nil)
        }
    }

    @Test func `Natural completion cancellation preserves cooldown encouragement`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true,
                messagingMode: .limitedScrolling,
                cooldownMinutes: 5
            )

            await sut.cancelTimerAlertsPreservingCooldown()

            let all = await pending(in: center)
            #expect(all.contains { $0.identifier == "rhoids.focusLock.cooldownComplete" })
            #expect(all.contains { $0.identifier == "rhoids.timer.complete" } == false)
            #expect(all.contains { $0.identifier == "rhoids.timer.warning" } == false)
        }
    }

    @Test func `Cancellation remains final while an addition is suspended`() async {
        await withCleanNotificationCenter { sut, center in
            await center.runBeforeNextAddition {
                await sut.cancelAll()
            }

            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            let timerRequests = await pending(in: center).filter {
                $0.identifier.hasPrefix("rhoids.timer.")
            }
            #expect(timerRequests.isEmpty)
        }
    }

    @Test func `Daily reminder uses stable identifier and selected time`() async throws {
        try await withCleanNotificationCenter { sut, center in
            await sut.scheduleDailyReminder(hour: 18, minute: 45)

            let request = try #require(
                await pending(matching: NotificationService.dailyReminderID, in: center)
            )
            let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
            #expect(trigger.repeats)
            #expect(trigger.dateComponents.hour == 18)
            #expect(trigger.dateComponents.minute == 45)
            #expect(request.content.title == "Keep your streak going")
        }
    }

    @Test func `Rescheduling daily reminder replaces previous time`() async throws {
        try await withCleanNotificationCenter { sut, center in
            await sut.scheduleDailyReminder(hour: 9, minute: 0)
            await sut.scheduleDailyReminder(hour: 20, minute: 15)

            let reminders = await pending(in: center).filter {
                $0.identifier == NotificationService.dailyReminderID
            }
            let request = try #require(reminders.first)
            let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
            #expect(reminders.count == 1)
            #expect(trigger.dateComponents.hour == 20)
            #expect(trigger.dateComponents.minute == 15)
        }
    }

    @Test func `Cancelling timer alerts preserves daily reminder`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleDailyReminder(hour: 9, minute: 0)
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault
            )
            await sut.cancelAll()

            let request = await pending(matching: NotificationService.dailyReminderID, in: center)
            #expect(request != nil)
        }
    }

    @Test func `Daily reminder can be cancelled independently`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleDailyReminder(hour: 9, minute: 0)
            await sut.cancelDailyReminder()

            let request = await pending(matching: NotificationService.dailyReminderID, in: center)
            #expect(request == nil)
        }
    }

    @Test func `Daily reminder reports a scheduling failure`() async {
        await withCleanNotificationCenter { sut, center in
            await center.failFutureAdditions()

            let scheduled = await sut.scheduleDailyReminder(hour: 9, minute: 0)

            #expect(scheduled == false)
            let request = await pending(matching: NotificationService.dailyReminderID, in: center)
            #expect(request == nil)
        }
    }

    @Test func `Failed reschedule preserves the previous daily reminder`() async throws {
        try await withCleanNotificationCenter { sut, center in
            let initiallyScheduled = await sut.scheduleDailyReminder(hour: 9, minute: 0)
            await center.failFutureAdditions()

            let rescheduled = await sut.scheduleDailyReminder(hour: 20, minute: 15)

            let request = try #require(
                await pending(matching: NotificationService.dailyReminderID, in: center)
            )
            let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
            #expect(initiallyScheduled)
            #expect(rescheduled == false)
            #expect(trigger.dateComponents.hour == 9)
            #expect(trigger.dateComponents.minute == 0)
        }
    }

    // MARK: - Schedule Flag Combinations

    @Test func `Schedule with both flags creates completion and warning`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Both",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            let all = await pending(in: center)
            let hasComplete = all.contains { $0.identifier == "rhoids.timer.complete" }
            let hasWarning = all.contains { $0.identifier == "rhoids.timer.warning" }
            #expect(hasComplete, "Completion notification should be scheduled when includeCompletion is true")
            #expect(hasWarning, "Warning notification should be scheduled when warningEnabled is true")
        }
    }

    @Test func `Schedule with includeCompletion false skips completion`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "NoComplete",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: false
            )

            let all = await pending(in: center)
            let hasComplete = all.contains { $0.identifier == "rhoids.timer.complete" }
            let hasWarning = all.contains { $0.identifier == "rhoids.timer.warning" }
            #expect(hasComplete == false, "Completion should not be scheduled when includeCompletion is false")
            #expect(hasWarning, "Warning should still be scheduled")
        }
    }

    @Test func `Schedule with warningEnabled false skips warning`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "NoWarning",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            let all = await pending(in: center)
            let hasComplete = all.contains { $0.identifier == "rhoids.timer.complete" }
            let hasWarning = all.contains { $0.identifier == "rhoids.timer.warning" }
            #expect(hasComplete, "Completion should still be scheduled")
            #expect(hasWarning == false, "Warning should not be scheduled when warningEnabled is false")
        }
    }

    @Test func `Schedule with both flags false creates nothing`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Nothing",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: false
            )

            let all = await pending(in: center)
            let timerRelated = all.filter {
                $0.identifier == "rhoids.timer.complete" || $0.identifier == "rhoids.timer.warning"
            }
            #expect(timerRelated.isEmpty, "No timer notifications should be scheduled when both flags are false")
        }
    }

    // MARK: - Notification Content

    @Test func `Completion content has correct title and category`() async throws {
        try await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Recommended",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            let req = try #require(await pending(matching: "rhoids.timer.complete", in: center),
                                    "Completion notification must exist")
            let content = req.content
            #expect(content.title == "Time's up!")
            #expect(content.body == "Stand up and walk away. Not done? That's fine. Come back later.")
            #expect(content.subtitle == "Recommended")
            #expect(content.categoryIdentifier == "TIMER_COMPLETE")
            #expect(content.threadIdentifier == "rhoids.timer")
            #expect(content.interruptionLevel == .timeSensitive)
        }
    }

    @Test func `Warning content has correct title and category`() async throws {
        try await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: false
            )

            let req = try #require(await pending(matching: "rhoids.timer.warning", in: center),
                                    "Warning notification must exist")
            let content = req.content
            #expect(content.title == "Almost done. Don't rush!")
            let warningBodies = TimerQuip.warningQuips.map(\.body)
            #expect(warningBodies.contains(content.body),
                    "Warning body should be one of the anti-rush warningQuips")
            #expect(content.categoryIdentifier == "TIMER_WARNING")
            #expect(content.threadIdentifier == "rhoids.timer")
            #expect(content.interruptionLevel == .timeSensitive)
        }
    }

    @Test func `Completion preset name appears as subtitle`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Max",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            let req = await pending(matching: "rhoids.timer.complete", in: center)
            #expect(req?.content.subtitle == "Max",
                    "The preset name should appear as the notification subtitle")
        }
    }

    // MARK: - Trigger Timing

    @Test func `Completion fires at endDate`() async throws {
        try await withCleanNotificationCenter { sut, center in
            let futureDate = Date().addingTimeInterval(90)

            await sut.schedule(
                endDate: futureDate,
                presetName: "Test",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            let req = try #require(await pending(matching: "rhoids.timer.complete", in: center))
            let trigger = try #require(req.trigger as? UNTimeIntervalNotificationTrigger)
            #expect(abs(trigger.timeInterval - 90) < 2,
                    "Completion trigger should fire ~90s from now")
            #expect(trigger.repeats == false, "Timer notifications should not repeat")
        }
    }

    @Test func `Warning fires 30 seconds before endDate`() async throws {
        try await withCleanNotificationCenter { sut, center in
            let futureDate = Date().addingTimeInterval(90)

            await sut.schedule(
                endDate: futureDate,
                presetName: "Test",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: false
            )

            let req = try #require(await pending(matching: "rhoids.timer.warning", in: center))
            let trigger = try #require(req.trigger as? UNTimeIntervalNotificationTrigger)
            #expect(abs(trigger.timeInterval - 60) < 2,
                    "Warning trigger should fire ~60s from now (90s - 30s)")
        }
    }

    // MARK: - Cancel

    @Test func `CancelAll removes all scheduled notifications`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            let before = await pending(in: center).filter {
                $0.identifier.hasPrefix("rhoids.timer.")
            }
            #expect(before.isEmpty == false, "Should have pending notifications before cancel")

            await sut.cancelAll()

            let after = await pending(in: center).filter {
                $0.identifier.hasPrefix("rhoids.timer.")
            }
            #expect(after.isEmpty, "All timer notifications should be removed after cancelAll")
        }
    }

    @Test func `Re-scheduling cancels previous notifications first`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "First",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            await sut.schedule(
                endDate: Date().addingTimeInterval(300),
                presetName: "Second",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            let all = await pending(in: center)
            let completions = all.filter { $0.identifier == "rhoids.timer.complete" }
            #expect(completions.count == 1,
                    "Re-scheduling should replace, not duplicate, the completion notification")
            #expect(completions.first?.content.subtitle == "Second",
                    "The replacement should carry the new preset name")
        }
    }

    // MARK: - Beep Notifications

    @Test func `Beep notifications use the stable ID prefix`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleBeepNotifications(
                duration: 180,
                endDate: Date().addingTimeInterval(180),
                sound: .systemDefault
            )

            let beeps = await pending(in: center).filter {
                $0.identifier.hasPrefix(NotificationService.beepIDPrefix)
            }
            #expect(beeps.isEmpty == false, "Beep notifications should use the stable prefix")
            for beep in beeps {
                #expect(beep.identifier.hasPrefix("rhoids.timer.beep."))
            }
        }
    }

    @Test func `Beep notification IDs encode remaining seconds`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleBeepNotifications(
                duration: 180,
                endDate: Date().addingTimeInterval(180),
                sound: .systemDefault
            )

            let beepIDs = await pending(in: center)
                .filter { $0.identifier.hasPrefix(NotificationService.beepIDPrefix) }
                .map { $0.identifier }
                .sorted()

            let expectedIDs = ["rhoids.timer.beep.120", "rhoids.timer.beep.150",
                               "rhoids.timer.beep.60", "rhoids.timer.beep.90"]
            #expect(beepIDs.sorted() == expectedIDs.sorted(),
                    "180s timer should have beep IDs for 150s, 120s, 90s, 60s remaining")
        }
    }

    @Test func `Beep content has correct category and interruption level`() async throws {
        try await withCleanNotificationCenter { sut, center in
            await sut.scheduleBeepNotifications(
                duration: 120,
                endDate: Date().addingTimeInterval(120),
                sound: .systemDefault
            )

            let beep = try #require(await pending(in: center).first {
                $0.identifier.hasPrefix(NotificationService.beepIDPrefix)
            })
            #expect(beep.content.categoryIdentifier == "TIMER_BEEP")
            #expect(beep.content.threadIdentifier == "rhoids.timer")
            #expect(beep.content.interruptionLevel == .timeSensitive)
            let beepBodies = TimerQuip.beepQuips.map(\.body)
            #expect(beepBodies.contains(beep.content.body),
                    "Beep body should be one of the anti-rush beepQuips")
        }
    }

    @Test(arguments: [
        (remaining: 150, expected: "2m 30s"),
        (remaining: 120, expected: "2 min"),
        (remaining:  90, expected: "1m 30s"),
        (remaining:  60, expected: "1 min"),
    ])
    func `Beep title formats remaining time correctly`(remaining: Int, expected: String) {
        let minutes = remaining / 60
        let seconds = remaining % 60
        let timeString = minutes > 0
            ? (seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes) min")
            : "\(seconds)s"
        #expect(timeString == expected,
                "Remaining \(remaining)s should format as '\(expected)'")
    }

    @Test func `Re-scheduling beeps clears previous beeps`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleBeepNotifications(
                duration: 180,
                endDate: Date().addingTimeInterval(180),
                sound: .systemDefault
            )

            let firstCount = await pending(in: center).filter {
                $0.identifier.hasPrefix(NotificationService.beepIDPrefix)
            }.count

            await sut.scheduleBeepNotifications(
                duration: 120,
                endDate: Date().addingTimeInterval(120),
                sound: .systemDefault
            )

            let secondCount = await pending(in: center).filter {
                $0.identifier.hasPrefix(NotificationService.beepIDPrefix)
            }.count

            #expect(firstCount == 4, "180s timer should produce 4 beeps")
            #expect(secondCount == 2, "120s timer should produce 2 beeps (not 4+2)")
        }
    }

    @Test func `CancelAll clears beep notifications too`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleBeepNotifications(
                duration: 180,
                endDate: Date().addingTimeInterval(180),
                sound: .systemDefault
            )

            await sut.cancelAll()

            let beeps = await pending(in: center).filter {
                $0.identifier.hasPrefix(NotificationService.beepIDPrefix)
            }
            #expect(beeps.isEmpty, "cancelAll should remove beep notifications")
        }
    }

    @Test func `Short timer produces no beeps`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleBeepNotifications(
                duration: 30,
                endDate: Date().addingTimeInterval(30),
                sound: .systemDefault
            )

            let beeps = await pending(in: center).filter {
                $0.identifier.hasPrefix(NotificationService.beepIDPrefix)
            }
            #expect(beeps.isEmpty, "A 30s timer should not schedule any beep notifications")
        }
    }

    @Test func `60-second timer produces no beeps`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleBeepNotifications(
                duration: 60,
                endDate: Date().addingTimeInterval(60),
                sound: .systemDefault
            )

            let beeps = await pending(in: center).filter {
                $0.identifier.hasPrefix(NotificationService.beepIDPrefix)
            }
            #expect(beeps.isEmpty,
                    "60s timer: only the warning handles T-30, so no separate beeps")
        }
    }

    // MARK: - Focus Lock Messaging

    @Test func `Completion uses neutral copy when messagingMode is nil`() async throws {
        try await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true,
                messagingMode: nil
            )

            let req = try #require(await pending(matching: "rhoids.timer.complete", in: center))
            #expect(req.content.title == "Time's up!",
                    "A nil messagingMode (e.g. Limited Scrolling that won't actually block) must fall back to the neutral default, never a path-specific claim")
        }
    }

    @Test func `Completion uses Phone-Free copy when messagingMode is phoneFree`() async throws {
        try await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true,
                messagingMode: .phoneFree
            )

            let req = try #require(await pending(matching: "rhoids.timer.complete", in: center))
            #expect(req.content.title == FocusLockMode.phoneFree.completionCopy(cooldownMinutes: 5).title)
            #expect(req.content.body == FocusLockMode.phoneFree.completionCopy(cooldownMinutes: 5).body)
        }
    }

    @Test func `Completion uses Limited Scrolling copy and cooldown minutes when messagingMode is limitedScrolling`() async throws {
        try await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(120),
                presetName: "Test",
                warningEnabled: false,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true,
                messagingMode: .limitedScrolling,
                cooldownMinutes: 15
            )

            let req = try #require(await pending(matching: "rhoids.timer.complete", in: center))
            #expect(req.content.title == "Apps Locked")
            #expect(req.content.body.contains("15"),
                    "Completion body should reflect the configured cooldown duration")
        }
    }

    // MARK: - Start Reminder

    @Test func `scheduleStartReminder schedules a notification for phoneFree`() async throws {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleStartReminder(mode: .phoneFree)

            let req = await pending(matching: "rhoids.timer.startReminder", in: center)
            #expect(req != nil, "Phone-Free must schedule the start reminder")
            #expect(req?.content.title == "PUT YOUR PHONE DOWN!")
        }
    }

    @Test func `scheduleStartReminder does nothing for limitedScrolling`() async throws {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleStartReminder(mode: .limitedScrolling)

            let req = await pending(matching: "rhoids.timer.startReminder", in: center)
            #expect(req == nil, "Limited Scrolling has nothing to remind at timer start")
        }
    }

    @Test func `CancelAll removes a pending start reminder`() async throws {
        await withCleanNotificationCenter { sut, center in
            await sut.scheduleStartReminder(mode: .phoneFree)
            await sut.cancelAll()

            let req = await pending(matching: "rhoids.timer.startReminder", in: center)
            #expect(req == nil, "cancelAll must clear the start reminder alongside completion/warning/beeps")
        }
    }

    // MARK: - Edge Cases

    @Test func `Scheduling with very long timer creates correct notification count`() async {
        await withCleanNotificationCenter { sut, center in
            await sut.schedule(
                endDate: Date().addingTimeInterval(600),
                presetName: "Long",
                warningEnabled: true,
                alarmSound: .systemDefault,
                warningSound: .systemDefault,
                includeCompletion: true
            )

            let all = await pending(in: center)
            let timerNotifs = all.filter { $0.identifier.hasPrefix("rhoids.timer.") }
            #expect(timerNotifs.count == 2,
                    "schedule() should create exactly 2 notifications (completion + warning)")
        }
    }
}
