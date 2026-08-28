import Foundation

/// The complete set of user preferences synced from iPhone to Apple Watch
/// via `WCSession.updateApplicationContext(_:)`.
///
/// iPhone sends this whenever any preference changes.
/// Watch receives it in `session(_:didReceiveApplicationContext:)` and
/// writes values to local UserDefaults so @AppStorage picks them up.
struct SyncedPreferences: Codable, Sendable, Equatable {
    var defaultPreset: String          // PresetTimer UUID string
    var notificationsEnabled: Bool
    var warningEnabled: Bool
    var hapticsEnabled: Bool
    var alarmSound: String             // AlarmSound.rawValue
    var warningSound: String           // AlarmSound.rawValue
    var appearanceMode: String         // AppearanceMode.rawValue
    var warningMode: String             // WarningMode.rawValue
    var timerStyle: String             // TimerStyle.rawValue (informational on Watch)
    var customDuration: TimeInterval   // Last custom duration set

    init(defaultPreset: String, notificationsEnabled: Bool, warningEnabled: Bool,
         warningMode: String = WarningMode.endOnly.rawValue, hapticsEnabled: Bool,
         alarmSound: String, warningSound: String, appearanceMode: String,
         timerStyle: String, customDuration: TimeInterval) {
        self.defaultPreset = defaultPreset
        self.notificationsEnabled = notificationsEnabled
        self.warningEnabled = warningEnabled
        self.warningMode = warningMode
        self.hapticsEnabled = hapticsEnabled
        self.alarmSound = alarmSound
        self.warningSound = warningSound
        self.appearanceMode = appearanceMode
        self.timerStyle = timerStyle
        self.customDuration = customDuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultPreset = try container.decode(String.self, forKey: .defaultPreset)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        warningEnabled = try container.decode(Bool.self, forKey: .warningEnabled)
        warningMode = try container.decodeIfPresent(String.self, forKey: .warningMode) ?? WarningMode.endOnly.rawValue
        hapticsEnabled = try container.decode(Bool.self, forKey: .hapticsEnabled)
        alarmSound = try container.decode(String.self, forKey: .alarmSound)
        warningSound = try container.decode(String.self, forKey: .warningSound)
        appearanceMode = try container.decode(String.self, forKey: .appearanceMode)
        timerStyle = try container.decode(String.self, forKey: .timerStyle)
        customDuration = try container.decode(TimeInterval.self, forKey: .customDuration)
    }

    /// Keys used for UserDefaults storage on Watch - aliases to `UserPreferences`
    /// and `PresetPreferences` so there's one source of truth per key.
    enum Keys {
        static let defaultPreset = PresetPreferences.defaultPresetKey
        static let notificationsEnabled = UserPreferences.notificationsEnabledKey
        static let warningEnabled = UserPreferences.warningEnabledKey
        static let hapticsEnabled = UserPreferences.hapticsEnabledKey
        static let warningMode = UserPreferences.warningModeKey
        static let alarmSound = "alarmSound.v1"
        static let warningSound = "warningSound.v1"
        static let appearanceMode = UserPreferences.appearanceModeKey
        static let timerStyle = UserPreferences.timerStyleKey
        static let customDuration = UserPreferences.lastCustomDurationKey
    }

    /// Build from the current state of iPhone UserDefaults.
    static func fromCurrentState() -> SyncedPreferences {
        let appGroupDefaults = UserDefaults(suiteName: SharedStateKeys.suiteName)
        let standardDefaults = UserDefaults.standard

        return SyncedPreferences(
            defaultPreset: appGroupDefaults?.string(forKey: Keys.defaultPreset) ?? "",
            notificationsEnabled: standardDefaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true,
            warningEnabled: standardDefaults.object(forKey: Keys.warningEnabled) as? Bool ?? true,
            warningMode: standardDefaults.string(forKey: Keys.warningMode) ?? WarningMode.endOnly.rawValue,
            hapticsEnabled: standardDefaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true,
            alarmSound: appGroupDefaults?.string(forKey: Keys.alarmSound) ?? "systemDefault",
            warningSound: appGroupDefaults?.string(forKey: Keys.warningSound) ?? "systemDefault",
            appearanceMode: standardDefaults.string(forKey: Keys.appearanceMode) ?? "system",
            timerStyle: standardDefaults.string(forKey: Keys.timerStyle) ?? "card",
            customDuration: standardDefaults.double(forKey: Keys.customDuration)
        )
    }

    /// Write received preferences to Watch local UserDefaults.
    /// The store is injectable so tests can target an isolated suite.
    func applyToLocalDefaults(to defaults: UserDefaults = .standard) {
        defaults.set(defaultPreset, forKey: Keys.defaultPreset)
        defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
        defaults.set(warningEnabled, forKey: Keys.warningEnabled)
        defaults.set(warningMode, forKey: Keys.warningMode)
        defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
        defaults.set(alarmSound, forKey: Keys.alarmSound)
        defaults.set(warningSound, forKey: Keys.warningSound)
        defaults.set(appearanceMode, forKey: Keys.appearanceMode)
        defaults.set(timerStyle, forKey: Keys.timerStyle)
        defaults.set(customDuration, forKey: Keys.customDuration)
    }

    /// Encode to dictionary for WCSession applicationContext.
    func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return ["syncedPreferences": dict]
    }

    /// Decode from WCSession applicationContext dictionary.
    static func from(context: [String: Any]) -> SyncedPreferences? {
        guard let dict = context["syncedPreferences"],
              let data = try? JSONSerialization.data(withJSONObject: dict)
        else { return nil }
        return try? JSONDecoder().decode(SyncedPreferences.self, from: data)
    }
}
