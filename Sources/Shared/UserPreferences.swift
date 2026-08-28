import Foundation

/// Central registry for UserDefaults keys and default values used across the
/// main app and the Watch extension.
///
/// Use the static computed properties for programmatic reads. For `@AppStorage`
/// bindings, pass the corresponding `*Key` constant as the store key.
enum UserPreferences {

    // MARK: - Keys

    static let notificationsEnabledKey = "notificationsEnabled"
    static let warningEnabledKey = "warningEnabled"
    static let hapticsEnabledKey = "hapticsEnabled"
    static let lastCustomDurationKey = "lastCustomDuration"
    static let warningModeKey = "warningMode"
    static let timerStyleKey = "timerStyle"
    static let appearanceModeKey = "appearanceMode"

    // MARK: - Accessors
    //
    // The properties read the app's real store; the `(in:)` variants exist so
    // tests can read from an isolated `UserDefaults` suite instead of mutating
    // shared global state.

    static var notificationsEnabled: Bool { notificationsEnabled(in: .standard) }

    static func notificationsEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: notificationsEnabledKey) as? Bool ?? true
    }

    static var warningEnabled: Bool { warningEnabled(in: .standard) }

    static func warningEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: warningEnabledKey) as? Bool ?? true
    }

    static var warningMode: WarningMode { warningMode(in: .standard) }

    static func warningMode(in defaults: UserDefaults) -> WarningMode {
        guard let raw = defaults.string(forKey: warningModeKey),
              let mode = WarningMode(rawValue: raw) else {
            return .endOnly
        }
        return mode
    }

    static var hapticsEnabled: Bool { hapticsEnabled(in: .standard) }

    static func hapticsEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: hapticsEnabledKey) as? Bool ?? true
    }

    static var timerAlertsEnabled: Bool {
        notificationsEnabled
    }

    static var timerWarningEnabled: Bool {
        timerAlertsEnabled && warningEnabled
    }

    static var timerAlertHapticsEnabled: Bool {
        timerAlertsEnabled && hapticsEnabled
    }
}
