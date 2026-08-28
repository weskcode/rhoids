import Testing
import Foundation
import FamilyControls
@testable import RHOIDS

struct FocusLockPreferencesTests {
    /// A fresh, isolated `UserDefaults` suite name per call so each test reads
    /// and writes its own storage - no shared App Group state, no save/restore.
    private func freshSuiteName() -> String {
        "test-focuslock-\(UUID().uuidString)"
    }

    /// Preferences bound to a brand-new (and therefore empty) suite.
    private func freshPreferences() -> FocusLockPreferences {
        FocusLockPreferences(suiteName: freshSuiteName())
    }

    // MARK: - Keys uniqueness & stability

    @Test func `Keys are non-empty and unique`() {
        let keys = [
            FocusLockPreferences.enabledKey,
            FocusLockPreferences.selectionKey,
            FocusLockPreferences.cooldownDurationKey,
            FocusLockPreferences.shieldsActiveKey,
            FocusLockPreferences.modeKey,
        ]
        #expect(Set(keys).count == keys.count, "All Focus Lock keys must be unique")
        for key in keys {
            #expect(key.isEmpty == false, "Focus Lock key must not be empty")
        }
    }

    @Test func `Keys do not collide with existing UserPreferences keys`() {
        let existingKeys: Set<String> = [
            UserPreferences.notificationsEnabledKey,
            UserPreferences.warningEnabledKey,
            UserPreferences.hapticsEnabledKey,
            UserPreferences.lastCustomDurationKey,
            UserPreferences.timerStyleKey,
            UserPreferences.appearanceModeKey,
        ]
        let focusLockKeys: Set<String> = [
            FocusLockPreferences.enabledKey,
            FocusLockPreferences.selectionKey,
            FocusLockPreferences.cooldownDurationKey,
            FocusLockPreferences.shieldsActiveKey,
            FocusLockPreferences.modeKey,
        ]
        let overlap = existingKeys.intersection(focusLockKeys)
        #expect(overlap.isEmpty, "Focus Lock keys must not collide with existing keys: \(overlap)")
    }

    @Test func `Key values are stable and must never change`() {
        #expect(FocusLockPreferences.enabledKey == "focusLockEnabled",
                "Changing this key would silently reset users' Focus Lock setting")
        #expect(FocusLockPreferences.selectionKey == "focusLockSelection",
                "Changing this key would lose users' blocked app selection")
        #expect(FocusLockPreferences.cooldownDurationKey == "focusLockCooldown",
                "Changing this key would reset cooldown duration to default")
        #expect(FocusLockPreferences.shieldsActiveKey == "focusLockShieldsActive",
                "Changing this key would break shield-active state tracking")
        #expect(FocusLockPreferences.modeKey == "focusLockMode",
                "Changing this key would reset users' chosen bathroom-focus path")
    }

    // MARK: - mode

    @Test func `mode defaults to phoneFree when nothing is stored`() {
        let prefs = freshPreferences()
        #expect(prefs.mode == .phoneFree,
                "An unset mode must default to the path that needs no Screen Time authorization")
    }

    @Test(arguments: FocusLockMode.allCases)
    func `mode round-trips each case`(mode: FocusLockMode) {
        let prefs = freshPreferences()
        prefs.mode = mode
        #expect(prefs.mode == mode)
    }

    @Test func `mode falls back to phoneFree when garbage is stored`() {
        let suiteName = freshSuiteName()
        UserDefaults(suiteName: suiteName)?.set("not-a-real-mode", forKey: FocusLockPreferences.modeKey)
        let prefs = FocusLockPreferences(suiteName: suiteName)
        #expect(prefs.mode == .phoneFree,
                "Corrupted/unrecognized raw value should fall back to the safe default, not crash")
    }

    // MARK: - isEnabled

    @Test func `isEnabled defaults to false when nothing is stored`() {
        let prefs = freshPreferences()
        #expect(prefs.isEnabled == false,
                "Focus Lock must be opt-in, defaulting to false")
    }

    @Test func `isEnabled round-trips true`() {
        let prefs = freshPreferences()
        prefs.isEnabled = true
        #expect(prefs.isEnabled == true)
    }

    @Test func `isEnabled round-trips false after being set to true`() {
        let prefs = freshPreferences()
        prefs.isEnabled = true
        prefs.isEnabled = false
        #expect(prefs.isEnabled == false)
    }

    // MARK: - cooldownDuration

    @Test func `Cooldown defaults to 300 seconds when nothing is stored`() {
        let prefs = freshPreferences()
        #expect(prefs.cooldownDuration == 300,
                "Default cooldown should be 5 minutes (300 seconds)")
    }

    @Test func `Default cooldown constant matches the getter default`() {
        #expect(FocusLockPreferences.defaultCooldownDuration == 300)
    }

    @Test(arguments: [TimeInterval(300), 600, 900, 1800])
    func `Cooldown round-trips supported durations`(duration: TimeInterval) {
        let prefs = freshPreferences()
        prefs.cooldownDuration = duration
        #expect(prefs.cooldownDuration == duration)
    }

    @Test func `Cooldown falls back to default when zero is stored`() {
        let suiteName = freshSuiteName()
        UserDefaults(suiteName: suiteName)?.set(0.0, forKey: FocusLockPreferences.cooldownDurationKey)
        let prefs = FocusLockPreferences(suiteName: suiteName)
        #expect(prefs.cooldownDuration == FocusLockPreferences.defaultCooldownDuration,
                "Zero stored value should fall back to default")
    }

    @Test func `Cooldown falls back to default when negative is stored`() {
        let suiteName = freshSuiteName()
        UserDefaults(suiteName: suiteName)?.set(-100.0, forKey: FocusLockPreferences.cooldownDurationKey)
        let prefs = FocusLockPreferences(suiteName: suiteName)
        #expect(prefs.cooldownDuration == FocusLockPreferences.defaultCooldownDuration,
                "Negative stored value should fall back to default")
    }

    // MARK: - shieldsActive

    @Test func `shieldsActive defaults to false`() {
        let prefs = freshPreferences()
        #expect(prefs.shieldsActive == false)
    }

    @Test func `shieldsActive round-trips true`() {
        let prefs = freshPreferences()
        prefs.shieldsActive = true
        #expect(prefs.shieldsActive == true)
    }

    @Test func `shieldsActive round-trips back to false`() {
        let prefs = freshPreferences()
        prefs.shieldsActive = true
        prefs.shieldsActive = false
        #expect(prefs.shieldsActive == false)
    }

    // MARK: - selection

    @Test func `Selection defaults to nil when nothing is stored`() {
        let prefs = freshPreferences()
        #expect(prefs.selection == nil)
    }

    @Test func `Empty selection round-trips through storage`() {
        let prefs = freshPreferences()
        let empty = FamilyActivitySelection()
        prefs.selection = empty
        let loaded = prefs.selection
        #expect(loaded == empty, "Empty FamilyActivitySelection should survive round-trip")
    }

    @Test func `Setting selection to nil clears storage`() {
        let prefs = freshPreferences()
        prefs.selection = FamilyActivitySelection()
        prefs.selection = nil
        #expect(prefs.selection == nil,
                "Setting selection to nil should clear the stored data")
    }

    @Test func `Corrupted selection data returns nil instead of crashing`() {
        let suiteName = freshSuiteName()
        UserDefaults(suiteName: suiteName)?.set(Data("not valid json".utf8), forKey: FocusLockPreferences.selectionKey)
        let prefs = FocusLockPreferences(suiteName: suiteName)
        #expect(prefs.selection == nil,
                "Corrupted data should return nil, not crash")
    }
}
