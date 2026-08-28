import Foundation

/// User's default preset, stored in the App Group so both the main app
/// and the widget extension can read/write it.
enum PresetPreferences {
    static let suiteName = SharedStateKeys.suiteName
    static let defaultPresetKey = "defaultPreset"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// The user's chosen default preset, or `.recommended` as a fallback.
    static var defaultPreset: PresetTimer {
        get {
            let storedID = defaults?.string(forKey: defaultPresetKey) ?? ""
            return PresetTimer.all.first { $0.id.uuidString == storedID } ?? .recommended
        }
        set {
            defaults?.set(newValue.id.uuidString, forKey: defaultPresetKey)
        }
    }
}
