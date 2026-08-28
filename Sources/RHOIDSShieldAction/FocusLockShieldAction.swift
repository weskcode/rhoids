import Foundation
import ManagedSettings

class FocusLockShieldAction: ShieldActionDelegate {
    private let store = ManagedSettingsStore(named: .init("com.wesley.RHOIDS.focusLock"))
    private let defaults = UserDefaults(suiteName: "group.com.wesley.RHOIDS")

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    private func response(for action: ShieldAction) -> ShieldActionResponse {
        clearExpiredCooldownIfNeeded()

        switch action {
        case .primaryButtonPressed:
            if #available(iOS 26.5, *) {
                return .openParentalControlsApp
            }
            return .close
        case .secondaryButtonPressed,
             .firstSecondarySubmenuItemPressed,
             .secondSecondarySubmenuItemPressed,
             .thirdSecondarySubmenuItemPressed:
            return .close
        @unknown default:
            return .close
        }
    }

    private func clearExpiredCooldownIfNeeded() {
        if let deadline = defaults?.object(forKey: "focusLockCooldownEndDate") as? Date,
           deadline <= .now {
            store.clearAllSettings()
            defaults?.set(false, forKey: "focusLockShieldsActive")
            defaults?.removeObject(forKey: "focusLockCooldownEndDate")
        }
    }
}
