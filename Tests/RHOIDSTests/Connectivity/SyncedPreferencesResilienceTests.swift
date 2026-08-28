import Foundation
import Testing
@testable import RHOIDS

struct SyncedPreferencesResilienceTests {

    // MARK: - Round-trip through WCSession dictionary format

    @Test("Full round-trip through toDictionary/from preserves all fields")
    func fullRoundTrip() throws {
        let original = SyncedPreferences(
            defaultPreset: "A1B2C3D4-0002-0000-0000-000000000002",
            notificationsEnabled: true,
            warningEnabled: false,
            warningMode: WarningMode.recurring.rawValue,
            hapticsEnabled: true,
            alarmSound: AlarmSound.gong.rawValue,
            warningSound: AlarmSound.birdsong.rawValue,
            appearanceMode: "dark",
            timerStyle: "ring",
            customDuration: 240
        )

        let dict = original.toDictionary()
        let decoded = try #require(SyncedPreferences.from(context: dict))

        #expect(decoded == original, "Round-trip should preserve exact equality")
    }

    @Test("from(context:) returns nil for empty dictionary")
    func emptyContextReturnsNil() {
        #expect(SyncedPreferences.from(context: [:]) == nil)
    }

    @Test("from(context:) returns nil when wrapper key is missing")
    func missingWrapperKey() {
        let dict: [String: Any] = ["wrongKey": ["notificationsEnabled": true]]
        #expect(SyncedPreferences.from(context: dict) == nil)
    }

    @Test("from(context:) returns nil for garbage data")
    func garbageData() {
        // Inner value is a valid JSON object but has wrong structure for SyncedPreferences
        let dict: [String: Any] = ["syncedPreferences": ["invalid": true, "keys": "only"]]
        #expect(SyncedPreferences.from(context: dict) == nil)
    }

    @Test("toDictionary never returns empty for valid preferences")
    func toDictionaryNeverEmpty() {
        let prefs = SyncedPreferences(
            defaultPreset: "",
            notificationsEnabled: false,
            warningEnabled: false,
            hapticsEnabled: false,
            alarmSound: "",
            warningSound: "",
            appearanceMode: "",
            timerStyle: "",
            customDuration: 0
        )
        let dict = prefs.toDictionary()
        #expect(dict.isEmpty == false)
        #expect(dict["syncedPreferences"] != nil)
    }

    // MARK: - Forward compatibility (missing warningMode key)

    @Test("Decoding without warningMode key defaults to endOnly")
    func missingWarningModeDefaultsToEndOnly() throws {
        let json: [String: Any] = [
            "defaultPreset": "some-id",
            "notificationsEnabled": true,
            "warningEnabled": true,
            "hapticsEnabled": true,
            "alarmSound": "systemDefault",
            "warningSound": "systemDefault",
            "appearanceMode": "system",
            "timerStyle": "card",
            "customDuration": 180.0
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(SyncedPreferences.self, from: data)

        #expect(decoded.warningMode == WarningMode.endOnly.rawValue,
                "Missing warningMode should default to endOnly for backward compatibility")
    }

    // MARK: - Equatable contract

    @Test("Two SyncedPreferences with identical values are equal")
    func equalityForIdenticalValues() {
        let a = makeDefault()
        let b = makeDefault()
        #expect(a == b)
    }

    @Test("Changing any single field breaks equality")
    func singleFieldChangeBreaksEquality() {
        let baseline = makeDefault()

        var diff1 = baseline; diff1.notificationsEnabled = false
        #expect(diff1 != baseline, "notificationsEnabled change should break equality")

        var diff2 = baseline; diff2.warningEnabled = false
        #expect(diff2 != baseline, "warningEnabled change should break equality")

        var diff3 = baseline; diff3.hapticsEnabled = false
        #expect(diff3 != baseline, "hapticsEnabled change should break equality")

        var diff4 = baseline; diff4.warningMode = WarningMode.recurring.rawValue
        #expect(diff4 != baseline, "warningMode change should break equality")

        var diff5 = baseline; diff5.alarmSound = AlarmSound.gong.rawValue
        #expect(diff5 != baseline, "alarmSound change should break equality")

        var diff6 = baseline; diff6.customDuration = 999
        #expect(diff6 != baseline, "customDuration change should break equality")

        var diff7 = baseline; diff7.defaultPreset = "different-uuid"
        #expect(diff7 != baseline, "defaultPreset change should break equality")

        var diff8 = baseline; diff8.timerStyle = "flip"
        #expect(diff8 != baseline, "timerStyle change should break equality")

        var diff9 = baseline; diff9.appearanceMode = "dark"
        #expect(diff9 != baseline, "appearanceMode change should break equality")

        var diff10 = baseline; diff10.warningSound = AlarmSound.crystal.rawValue
        #expect(diff10 != baseline, "warningSound change should break equality")
    }

    // MARK: - applyToLocalDefaults + readback

    @Test("applyToLocalDefaults writes all keys to UserDefaults")
    func applyWritesAllKeys() throws {
        let prefs = SyncedPreferences(
            defaultPreset: "test-preset-id",
            notificationsEnabled: false,
            warningEnabled: true,
            warningMode: WarningMode.recurring.rawValue,
            hapticsEnabled: false,
            alarmSound: AlarmSound.harp.rawValue,
            warningSound: AlarmSound.zen.rawValue,
            appearanceMode: "dark",
            timerStyle: "dial",
            customDuration: 420
        )

        let suiteName = "test-syncedprefs-\(UUID().uuidString)"
        let d = try #require(UserDefaults(suiteName: suiteName))
        defer { d.removePersistentDomain(forName: suiteName) }

        prefs.applyToLocalDefaults(to: d)

        #expect(d.string(forKey: SyncedPreferences.Keys.defaultPreset) == "test-preset-id")
        #expect(d.bool(forKey: SyncedPreferences.Keys.notificationsEnabled) == false)
        #expect(d.bool(forKey: SyncedPreferences.Keys.warningEnabled) == true)
        #expect(d.string(forKey: SyncedPreferences.Keys.warningMode) == WarningMode.recurring.rawValue)
        #expect(d.bool(forKey: SyncedPreferences.Keys.hapticsEnabled) == false)
        #expect(d.string(forKey: SyncedPreferences.Keys.alarmSound) == AlarmSound.harp.rawValue)
        #expect(d.string(forKey: SyncedPreferences.Keys.warningSound) == AlarmSound.zen.rawValue)
        #expect(d.string(forKey: SyncedPreferences.Keys.appearanceMode) == "dark")
        #expect(d.string(forKey: SyncedPreferences.Keys.timerStyle) == "dial")
        #expect(d.double(forKey: SyncedPreferences.Keys.customDuration) == 420)
    }

    // MARK: - Key alignment with UserPreferences

    @Test("SyncedPreferences.Keys align with UserPreferences key constants")
    func keysAlignWithUserPreferences() {
        #expect(SyncedPreferences.Keys.notificationsEnabled == UserPreferences.notificationsEnabledKey)
        #expect(SyncedPreferences.Keys.warningEnabled == UserPreferences.warningEnabledKey)
        #expect(SyncedPreferences.Keys.hapticsEnabled == UserPreferences.hapticsEnabledKey)
        #expect(SyncedPreferences.Keys.warningMode == UserPreferences.warningModeKey)
        #expect(SyncedPreferences.Keys.appearanceMode == UserPreferences.appearanceModeKey)
        #expect(SyncedPreferences.Keys.timerStyle == UserPreferences.timerStyleKey)
        #expect(SyncedPreferences.Keys.customDuration == UserPreferences.lastCustomDurationKey)
    }

    @Test("SyncedPreferences.Keys.defaultPreset aligns with PresetPreferences")
    func defaultPresetKeyAligns() {
        #expect(SyncedPreferences.Keys.defaultPreset == PresetPreferences.defaultPresetKey)
    }

    // MARK: - Helpers

    private func makeDefault() -> SyncedPreferences {
        SyncedPreferences(
            defaultPreset: "A1B2C3D4-0002-0000-0000-000000000002",
            notificationsEnabled: true,
            warningEnabled: true,
            warningMode: WarningMode.endOnly.rawValue,
            hapticsEnabled: true,
            alarmSound: AlarmSound.systemDefault.rawValue,
            warningSound: AlarmSound.systemDefault.rawValue,
            appearanceMode: "system",
            timerStyle: "card",
            customDuration: 180
        )
    }
}
