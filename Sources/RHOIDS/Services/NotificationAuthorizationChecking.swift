import UserNotifications

protocol NotificationAuthorizationChecking: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
}

protocol NotificationPermissionRequesting: Sendable {
    func requestAuthorization() async throws -> Bool
}

extension NotificationService: NotificationAuthorizationChecking, NotificationPermissionRequesting {}
