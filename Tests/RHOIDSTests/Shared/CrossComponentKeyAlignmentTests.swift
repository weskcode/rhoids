import Foundation
import Testing
@testable import RHOIDS

/// Validates that all the different systems that read/write UserDefaults keys
/// agree on the exact key strings. A key mismatch between iPhone and Watch,
/// or between SharedStateService and TimerService, causes silent data loss
/// where one side writes and the other reads from a different key.
@MainActor
struct CrossComponentKeyAlignmentTests {

    // MARK: - SharedStateKeys ↔ SharedStateService alignment

    @Test("SharedStateService uses SharedStateKeys.timerEndDate for endDate")
    func sharedStateEndDateKey() throws {
        let suiteName = "com.test.rhoids.keyalign-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let svc = SharedStateService(suiteName: suiteName)
        let endDate = Date(timeIntervalSince1970: 2_000_000_000)
        svc.setTimer(endDate: endDate, presetName: "Test", duration: 60)

        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let stored = try #require(defaults.object(forKey: SharedStateKeys.timerEndDate) as? Date,
                                  "endDate should be written under SharedStateKeys.timerEndDate")
        #expect(abs(stored.timeIntervalSince(endDate)) < 0.01)
    }

    @Test("SharedStateService uses SharedStateKeys.timerIsRunning for running flag")
    func sharedStateIsRunningKey() throws {
        let suiteName = "com.test.rhoids.keyalign-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let svc = SharedStateService(suiteName: suiteName)
        svc.setTimer(endDate: Date().addingTimeInterval(60), presetName: "Test", duration: 60)

        let defaults = try #require(UserDefaults(suiteName: suiteName))
        #expect(defaults.bool(forKey: SharedStateKeys.timerIsRunning) == true)

        svc.clearTimer()
        #expect(defaults.bool(forKey: SharedStateKeys.timerIsRunning) == false)
    }

    @Test("SharedStateService uses SharedStateKeys.timerPresetName for preset name")
    func sharedStatePresetNameKey() throws {
        let suiteName = "com.test.rhoids.keyalign-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let svc = SharedStateService(suiteName: suiteName)
        svc.setTimer(endDate: Date().addingTimeInterval(60), presetName: "Recommended", duration: 180)

        let defaults = try #require(UserDefaults(suiteName: suiteName))
        #expect(defaults.string(forKey: SharedStateKeys.timerPresetName) == "Recommended")
    }

    @Test("SharedStateService uses SharedStateKeys.timerDuration for duration")
    func sharedStateDurationKey() throws {
        let suiteName = "com.test.rhoids.keyalign-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let svc = SharedStateService(suiteName: suiteName)
        svc.setTimer(endDate: Date().addingTimeInterval(60), presetName: "Test", duration: 300)

        let defaults = try #require(UserDefaults(suiteName: suiteName))
        #expect(defaults.double(forKey: SharedStateKeys.timerDuration) == 300)
    }

    // MARK: - SharedStateKeys literal stability

    @Test("SharedStateKeys suite name is stable")
    func suiteNameStable() {
        #expect(SharedStateKeys.suiteName == "group.com.wesley.RHOIDS",
                "Changing the App Group name breaks all cross-process communication")
    }

    @Test("SharedStateKeys key names are stable")
    func keyNamesStable() {
        #expect(SharedStateKeys.timerEndDate == "activeTimerEndDate")
        #expect(SharedStateKeys.timerIsRunning == "timerIsRunning")
        #expect(SharedStateKeys.timerPresetName == "activeTimerPresetName")
        #expect(SharedStateKeys.timerDuration == "activeTimerDuration")
    }

    // MARK: - UserPreferences key stability

    @Test("UserPreferences key constants are stable")
    func userPreferencesKeysStable() {
        #expect(UserPreferences.notificationsEnabledKey == "notificationsEnabled")
        #expect(UserPreferences.warningEnabledKey == "warningEnabled")
        #expect(UserPreferences.hapticsEnabledKey == "hapticsEnabled")
        #expect(UserPreferences.lastCustomDurationKey == "lastCustomDuration")
        #expect(UserPreferences.warningModeKey == "warningMode")
        #expect(UserPreferences.timerStyleKey == "timerStyle")
        #expect(UserPreferences.appearanceModeKey == "appearanceMode")
    }

    // MARK: - PresetPreferences key alignment

    @Test("PresetPreferences uses the App Group suite")
    func presetPreferencesUsesAppGroup() {
        #expect(PresetPreferences.suiteName == SharedStateKeys.suiteName,
                "PresetPreferences must use the same App Group as SharedStateService")
    }

    @Test("PresetPreferences.defaultPresetKey is stable")
    func presetPreferencesKeyStable() {
        #expect(PresetPreferences.defaultPresetKey == "defaultPreset")
    }

    // MARK: - FocusLockPreferences key stability

    @Test("FocusLockPreferences key constants are stable")
    func focusLockKeysStable() {
        #expect(FocusLockPreferences.enabledKey == "focusLockEnabled")
        #expect(FocusLockPreferences.selectionKey == "focusLockSelection")
        #expect(FocusLockPreferences.cooldownDurationKey == "focusLockCooldown")
        #expect(FocusLockPreferences.shieldsActiveKey == "focusLockShieldsActive")
    }

    @Test("FocusLockPreferences default cooldown is 5 minutes")
    func focusLockDefaultCooldown() {
        #expect(FocusLockPreferences.defaultCooldownDuration == 300)
    }

    // MARK: - Enum raw value stability (persistence contract)

    @Test("WarningMode raw values are stable")
    func warningModeRawValues() {
        #expect(WarningMode.endOnly.rawValue == "endOnly")
        #expect(WarningMode.recurring.rawValue == "recurring")
    }

    @Test("TimerStyle raw values are stable")
    func timerStyleRawValues() {
        let expected: [(TimerStyle, String)] = [
            (.card, "card"), (.ring, "ring"), (.progress, "progress"),
            (.flip, "flip"), (.dial, "dial"), (.gauge, "gauge")
        ]
        for (style, raw) in expected {
            #expect(style.rawValue == raw,
                    "TimerStyle.\(style) raw value changed - breaks persisted preferences")
        }
    }

    @Test("AppearanceMode raw values are stable")
    func appearanceModeRawValues() {
        #expect(AppearanceMode.system.rawValue == "system")
        #expect(AppearanceMode.light.rawValue == "light")
        #expect(AppearanceMode.dark.rawValue == "dark")
    }

    // MARK: - SyncedPreferences ↔ SoundPreferences key alignment

    @Test("SyncedPreferences alarm/warning keys match SoundPreferences keys")
    func soundPreferencesKeysAlign() {
        // SoundPreferences uses private keys but they must match
        // SyncedPreferences.Keys for Watch sync to work correctly.
        #expect(SyncedPreferences.Keys.alarmSound == "alarmSound.v1")
        #expect(SyncedPreferences.Keys.warningSound == "warningSound.v1")
    }
}
