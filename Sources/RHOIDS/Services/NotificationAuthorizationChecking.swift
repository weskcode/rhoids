import UserNotifications

protocol NotificationPermissionRequesting: Sendable {
    func requestAuthorization() async throws -> Bool
}

extension NotificationService: NotificationPermissionRequesting {}
