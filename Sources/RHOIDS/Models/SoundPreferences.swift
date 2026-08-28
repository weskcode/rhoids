import Foundation

/// Reads/writes the user's chosen alarm + warning sounds.
/// Backed by the shared `App Group` so the widget extension can read
/// the same values if it ever needs to render the chosen tone name.
enum SoundPreferences {
    private static let suiteName = SharedStateKeys.suiteName
    private static let alarmKey = "alarmSound.v1"
    private static let warningKey = "warningSound.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static var alarm: AlarmSound {
        get {
            guard let raw = defaults?.string(forKey: alarmKey),
                  let sound = AlarmSound(rawValue: raw) else { return .systemDefault }
            return sound
        }
        set {
            defaults?.set(newValue.rawValue, forKey: alarmKey)
        }
    }

    static var warning: AlarmSound {
        get {
            guard let raw = defaults?.string(forKey: warningKey),
                  let sound = AlarmSound(rawValue: raw) else { return .systemDefault }
            return sound
        }
        set {
            defaults?.set(newValue.rawValue, forKey: warningKey)
        }
    }
}
