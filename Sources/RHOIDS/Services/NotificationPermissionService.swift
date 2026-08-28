import Foundation
import os.log

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "Notifications")

/// Owns the single system notification-permission request for a session.
/// RHOIDS asks only from explanatory onboarding or when the user starts a
/// notification-dependent timer; it never displays recurring launch nags.
@MainActor
final class NotificationPermissionService {
    private var hasRequestedThisSession = false

    @discardableResult
    func requestPermission(using service: some NotificationPermissionRequesting) async -> Bool {
        guard !hasRequestedThisSession else { return false }
        hasRequestedThisSession = true
        do {
            return try await service.requestAuthorization()
        } catch {
            hasRequestedThisSession = false
            log.error("requestPermission failed: \(error)")
            return false
        }
    }
}
