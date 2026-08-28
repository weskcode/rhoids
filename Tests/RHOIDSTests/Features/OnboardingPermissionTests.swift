import Testing
import Foundation
@testable import RHOIDS

@MainActor
struct OnboardingPermissionTests {
    @Test("requestPermission respects session guard")
    func requestPermissionRespectsSessionGuard() async {
        let sut = NotificationPermissionService()
        let mock = MockNotificationPermissionRequester()

        await sut.requestPermission(using: mock)
        await sut.requestPermission(using: mock)

        let count = await mock.requestCount
        #expect(count == 1,
                "Second call should be blocked by session guard")
    }

    @Test("Fresh service allows permission request")
    func freshServiceAllowsPermissionRequest() async {
        let sut1 = NotificationPermissionService()
        let sut2 = NotificationPermissionService()
        let mock = MockNotificationPermissionRequester(outcomes: [.success(true), .success(true)])

        await sut1.requestPermission(using: mock)
        await sut2.requestPermission(using: mock)

        let count = await mock.requestCount
        #expect(count == 2,
                "Independent service instances should each allow one request")
    }

    @Test("Permission request failure allows retry in same session")
    func permissionRequestFailureAllowsRetry() async {
        let sut = NotificationPermissionService()
        let mock = MockNotificationPermissionRequester(outcomes: [.failure, .success(true)])

        await sut.requestPermission(using: mock)
        await sut.requestPermission(using: mock)

        let count = await mock.requestCount
        #expect(count == 2,
                "A failed request should not block a subsequent retry")
    }

    @Test("Notification page is present in onboarding for inline permission request")
    func notificationPageExists() {
        let hasNotificationPage = OnboardingPage.all.contains {
            $0.id == OnboardingPage.notifications.id
        }
        #expect(hasNotificationPage,
                "Onboarding must include the notifications page for inline permission requests")
    }
}
