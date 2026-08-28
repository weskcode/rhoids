import Testing
import Foundation
@testable import RHOIDS

enum MockNotificationPermissionRequestOutcome: Sendable {
    case success(Bool)
    case failure
}

actor MockNotificationPermissionRequester: NotificationPermissionRequesting {
    private var outcomes: [MockNotificationPermissionRequestOutcome]
    private(set) var requestCount = 0

    init(outcomes: [MockNotificationPermissionRequestOutcome] = [.success(true)]) {
        self.outcomes = outcomes
    }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        let outcome = outcomes.isEmpty ? .success(true) : outcomes.removeFirst()
        switch outcome {
        case .success(let granted): return granted
        case .failure: throw MockNotificationPermissionRequestError.failed
        }
    }
}

private enum MockNotificationPermissionRequestError: Error {
    case failed
}

@MainActor
struct NotificationPermissionServiceTests {
    @Test("Successful permission request is attempted once per session")
    func requestPermissionGuard() async {
        let sut = NotificationPermissionService()
        let requester = MockNotificationPermissionRequester()

        #expect(await sut.requestPermission(using: requester))
        #expect(await sut.requestPermission(using: requester) == false)
        #expect(await requester.requestCount == 1)
    }

    @Test("A declined system decision is still a completed request")
    func declinedRequestIsNotRepeated() async {
        let sut = NotificationPermissionService()
        let requester = MockNotificationPermissionRequester(outcomes: [.success(false), .success(true)])

        #expect(await sut.requestPermission(using: requester) == false)
        #expect(await sut.requestPermission(using: requester) == false)
        #expect(await requester.requestCount == 1)
    }

    @Test("A request error can be retried")
    func requestErrorCanRetry() async {
        let sut = NotificationPermissionService()
        let requester = MockNotificationPermissionRequester(outcomes: [.failure, .success(true)])

        #expect(await sut.requestPermission(using: requester) == false)
        #expect(await sut.requestPermission(using: requester))
        #expect(await requester.requestCount == 2)
    }
}
