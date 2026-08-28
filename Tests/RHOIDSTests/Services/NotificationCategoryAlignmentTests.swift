import Testing
import Foundation
import UserNotifications
@testable import RHOIDS

struct NotificationActionExpectation: Sendable, CustomTestStringConvertible {
    let actionIdentifier: String
    let categoryIdentifier: String
    let expectedActionIdentifier: String

    var testDescription: String {
        "action=\(actionIdentifier), category=\(categoryIdentifier)"
    }
}

let notificationActionExpectations: [NotificationActionExpectation] = [
    NotificationActionExpectation(
        actionIdentifier: UNNotificationDismissActionIdentifier,
        categoryIdentifier: NotificationDelegate.timerCompleteCategoryID,
        expectedActionIdentifier: NotificationDelegate.timerDismissActionID
    ),
    NotificationActionExpectation(
        actionIdentifier: UNNotificationDismissActionIdentifier,
        categoryIdentifier: "TIMER_WARNING",
        expectedActionIdentifier: UNNotificationDismissActionIdentifier
    ),
    NotificationActionExpectation(
        actionIdentifier: UNNotificationDismissActionIdentifier,
        categoryIdentifier: "TIMER_BEEP",
        expectedActionIdentifier: UNNotificationDismissActionIdentifier
    ),
    NotificationActionExpectation(
        actionIdentifier: NotificationDelegate.timerDismissActionID,
        categoryIdentifier: NotificationDelegate.timerCompleteCategoryID,
        expectedActionIdentifier: NotificationDelegate.timerDismissActionID
    ),
    NotificationActionExpectation(
        actionIdentifier: NotificationDelegate.timerSnoozeActionID,
        categoryIdentifier: NotificationDelegate.timerCompleteCategoryID,
        expectedActionIdentifier: NotificationDelegate.timerSnoozeActionID
    ),
    NotificationActionExpectation(
        actionIdentifier: UNNotificationDefaultActionIdentifier,
        categoryIdentifier: NotificationDelegate.timerCompleteCategoryID,
        expectedActionIdentifier: UNNotificationDefaultActionIdentifier
    )
]

struct NotificationCategoryAlignmentTests {

    @Test func `Completion category ID matches between AppDelegate and NotificationService`() async {
        let center = TestNotificationSchedulingCenter()
        let sut = NotificationService(center: center)

        await sut.schedule(
            endDate: Date().addingTimeInterval(120),
            presetName: "Test",
            warningEnabled: false,
            alarmSound: .systemDefault,
            warningSound: .systemDefault,
            includeCompletion: true
        )

        let req = await center.pendingNotificationRequests()
            .first { $0.identifier == "rhoids.timer.complete" }
        #expect(req?.content.categoryIdentifier == "TIMER_COMPLETE",
                "NotificationService must use the same category ID that AppDelegate registers")
    }

    @Test func `Warning category ID matches between AppDelegate and NotificationService`() async {
        let center = TestNotificationSchedulingCenter()
        let sut = NotificationService(center: center)

        await sut.schedule(
            endDate: Date().addingTimeInterval(120),
            presetName: "Test",
            warningEnabled: true,
            alarmSound: .systemDefault,
            warningSound: .systemDefault,
            includeCompletion: false
        )

        let req = await center.pendingNotificationRequests()
            .first { $0.identifier == "rhoids.timer.warning" }
        #expect(req?.content.categoryIdentifier == "TIMER_WARNING",
                "NotificationService must use the same category ID that AppDelegate registers")
    }

    @Test func `Beep category ID matches between AppDelegate and NotificationService`() async throws {
        let center = TestNotificationSchedulingCenter()
        let sut = NotificationService(center: center)

        await sut.scheduleBeepNotifications(
            duration: 120,
            endDate: Date().addingTimeInterval(120),
            sound: .systemDefault
        )

        let beep = try #require(
            await center.pendingNotificationRequests()
                .first { $0.identifier.hasPrefix(NotificationService.beepIDPrefix) }
        )
        #expect(beep.content.categoryIdentifier == "TIMER_BEEP",
                "NotificationService must use the same category ID that AppDelegate registers")
    }

    @Test func `Foreground suppression IDs match scheduled notification IDs`() {
        #expect("rhoids.timer.complete" == "rhoids.timer.complete",
                "NotificationDelegate.willPresent checks this literal - it must match scheduleAlarm's ID")
        #expect("rhoids.timer.warning" == "rhoids.timer.warning",
                "NotificationDelegate.willPresent checks this literal - it must match scheduleWarning's ID")
        #expect(NotificationService.beepIDPrefix == "rhoids.timer.beep.",
                "NotificationDelegate.willPresent uses this prefix to suppress foreground beeps")
    }

    @Test func `Completion banner dismissal maps to timer dismiss action`() {
        let actionID = NotificationDelegate.normalizedActionID(
            actionIdentifier: UNNotificationDismissActionIdentifier,
            categoryIdentifier: NotificationDelegate.timerCompleteCategoryID
        )

        #expect(actionID == NotificationDelegate.timerDismissActionID,
                "The banner close control must dismiss the completed timer just like the Dismiss action")
    }

    @Test func `Non-completion banner dismissal does not stop timer`() {
        let actionID = NotificationDelegate.normalizedActionID(
            actionIdentifier: UNNotificationDismissActionIdentifier,
            categoryIdentifier: "TIMER_WARNING"
        )

        #expect(actionID == UNNotificationDismissActionIdentifier,
                "Only dismissing the completion alarm should turn into a timer dismiss")
    }

    @Test(
        "Notification action normalization only rewrites completion banner dismiss",
        arguments: notificationActionExpectations
    )
    func notificationActionNormalizationMatrix(expectation: NotificationActionExpectation) {
        let actionID = NotificationDelegate.normalizedActionID(
            actionIdentifier: expectation.actionIdentifier,
            categoryIdentifier: expectation.categoryIdentifier
        )

        #expect(actionID == expectation.expectedActionIdentifier)
    }
}
