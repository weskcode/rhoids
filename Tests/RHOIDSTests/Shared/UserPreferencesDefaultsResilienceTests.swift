import Foundation
import Testing
@testable import RHOIDS

struct TimerPreferenceExpectation: Sendable, CustomTestStringConvertible {
    let notificationsEnabled: Bool
    let warningEnabled: Bool
    let hapticsEnabled: Bool
    let expectedAlerts: Bool
    let expectedWarning: Bool
    let expectedHaptics: Bool

    var testDescription: String {
        "notifications=\(notificationsEnabled), warning=\(warningEnabled), haptics=\(hapticsEnabled)"
    }
}

let timerPreferenceExpectations: [TimerPreferenceExpectation] = [
    TimerPreferenceExpectation(
        notificationsEnabled: false,
        warningEnabled: false,
        hapticsEnabled: false,
        expectedAlerts: false,
        expectedWarning: false,
        expectedHaptics: false
    ),
    TimerPreferenceExpectation(
        notificationsEnabled: false,
        warningEnabled: false,
        hapticsEnabled: true,
        expectedAlerts: false,
        expectedWarning: false,
        expectedHaptics: false
    ),
    TimerPreferenceExpectation(
        notificationsEnabled: false,
        warningEnabled: true,
        hapticsEnabled: false,
        expectedAlerts: false,
        expectedWarning: false,
        expectedHaptics: false
    ),
    TimerPreferenceExpectation(
        notificationsEnabled: false,
        warningEnabled: true,
        hapticsEnabled: true,
        expectedAlerts: false,
        expectedWarning: false,
        expectedHaptics: false
    ),
    TimerPreferenceExpectation(
        notificationsEnabled: true,
        warningEnabled: false,
        hapticsEnabled: false,
        expectedAlerts: true,
        expectedWarning: false,
        expectedHaptics: false
    ),
    TimerPreferenceExpectation(
        notificationsEnabled: true,
        warningEnabled: false,
        hapticsEnabled: true,
        expectedAlerts: true,
        expectedWarning: false,
        expectedHaptics: true
    ),
    TimerPreferenceExpectation(
        notificationsEnabled: true,
        warningEnabled: true,
        hapticsEnabled: false,
        expectedAlerts: true,
        expectedWarning: true,
        expectedHaptics: false
    ),
    TimerPreferenceExpectation(
        notificationsEnabled: true,
        warningEnabled: true,
        hapticsEnabled: true,
        expectedAlerts: true,
        expectedWarning: true,
        expectedHaptics: true
    )
]

/// Tests that UserPreferences accessors are resilient to corrupt, missing,
/// or type-mismatched values in UserDefaults. These situations occur when:
/// - A user upgrades from a version that didn't have a particular key
/// - A future version changes the type stored under a key
/// - UserDefaults is partially cleared or corrupted on disk
struct UserPreferencesDefaultsResilienceTests {

    // MARK: - Default values when keys are absent

    @Test("notificationsEnabled defaults to true when key is absent")
    func notificationsEnabledDefault() {
        withCleanKey(UserPreferences.notificationsEnabledKey) {
            #expect(UserPreferences.notificationsEnabled == true)
        }
    }

    @Test("warningEnabled defaults to true when key is absent")
    func warningEnabledDefault() {
        withCleanKey(UserPreferences.warningEnabledKey) {
            #expect(UserPreferences.warningEnabled == true)
        }
    }

    @Test("hapticsEnabled defaults to true when key is absent")
    func hapticsEnabledDefault() {
        withCleanKey(UserPreferences.hapticsEnabledKey) {
            #expect(UserPreferences.hapticsEnabled == true)
        }
    }

    @Test("warningMode defaults to .endOnly when key is absent")
    func warningModeDefault() {
        withCleanKey(UserPreferences.warningModeKey) {
            #expect(UserPreferences.warningMode == .endOnly)
        }
    }

    // MARK: - Corrupt value resilience

    @Test("warningMode falls back to .endOnly for unknown raw value")
    func warningModeCorrupt() {
        withCleanKey(UserPreferences.warningModeKey) {
            UserDefaults.standard.set("futureMode", forKey: UserPreferences.warningModeKey)
            #expect(UserPreferences.warningMode == .endOnly,
                    "Unknown raw value should gracefully fall back to .endOnly")
        }
    }

    @Test("warningMode falls back to .endOnly when stored value is wrong type")
    func warningModeWrongType() {
        withCleanKey(UserPreferences.warningModeKey) {
            UserDefaults.standard.set(42, forKey: UserPreferences.warningModeKey)
            #expect(UserPreferences.warningMode == .endOnly,
                    "Integer stored where string expected should fall back gracefully")
        }
    }

    @Test("notificationsEnabled handles explicit false correctly")
    func notificationsExplicitFalse() {
        withCleanKey(UserPreferences.notificationsEnabledKey) {
            UserDefaults.standard.set(false, forKey: UserPreferences.notificationsEnabledKey)
            #expect(UserPreferences.notificationsEnabled == false,
                    "Explicit false must not be overridden by the default true")
        }
    }

    @Test("warningEnabled handles explicit false correctly")
    func warningExplicitFalse() {
        withCleanKey(UserPreferences.warningEnabledKey) {
            UserDefaults.standard.set(false, forKey: UserPreferences.warningEnabledKey)
            #expect(UserPreferences.warningEnabled == false)
        }
    }

    @Test("hapticsEnabled handles explicit false correctly")
    func hapticsExplicitFalse() {
        withCleanKey(UserPreferences.hapticsEnabledKey) {
            UserDefaults.standard.set(false, forKey: UserPreferences.hapticsEnabledKey)
            #expect(UserPreferences.hapticsEnabled == false)
        }
    }

    // MARK: - WarningMode exhaustive validation

    @Test("All WarningMode cases survive raw value round-trip")
    func warningModeRoundTrip() {
        for mode in WarningMode.allCases {
            withCleanKey(UserPreferences.warningModeKey) {
                UserDefaults.standard.set(mode.rawValue, forKey: UserPreferences.warningModeKey)
                #expect(UserPreferences.warningMode == mode,
                        "\(mode) did not survive round-trip")
            }
        }
    }

    @Test("WarningMode has exactly 2 cases")
    func warningModeCaseCount() {
        #expect(WarningMode.allCases.count == 2,
                "If a new mode is added, update the beep scheduling logic and this test")
    }

    @Test("WarningMode displayName is non-empty for all cases")
    func warningModeDisplayNames() {
        for mode in WarningMode.allCases {
            #expect(mode.displayName.isEmpty == false)
        }
    }

    @Test("WarningMode settingsDescription is non-empty for all cases")
    func warningModeDescriptions() {
        for mode in WarningMode.allCases {
            #expect(mode.settingsDescription.isEmpty == false)
        }
    }

    @Test("WarningMode Identifiable id matches rawValue")
    func warningModeIdentifiable() {
        for mode in WarningMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
    }

    // MARK: - TimerPreferences default values

    @Test("TimerPreferences default init has sensible values")
    func timerPreferencesDefaults() {
        let prefs = TimerService.TimerPreferences()
        #expect(prefs.notificationsEnabled == true)
        #expect(prefs.warningEnabled == true)
        #expect(prefs.warningMode == .endOnly)
        #expect(prefs.hapticsEnabled == true)
        #expect(prefs.alarmSound == .systemDefault)
        #expect(prefs.warningSound == .systemDefault)
        #expect(prefs.timerAlertsEnabled == true)
        #expect(prefs.timerWarningEnabled == true)
        #expect(prefs.timerAlertHapticsEnabled == true)
    }

    @Test("Timer Alerts off disables effective warning and haptics")
    func timerAlertsOffDisablesDerivedAlertPreferences() {
        withCleanKeys([
            UserPreferences.notificationsEnabledKey,
            UserPreferences.warningEnabledKey,
            UserPreferences.hapticsEnabledKey
        ]) {
            UserDefaults.standard.set(false, forKey: UserPreferences.notificationsEnabledKey)
            UserDefaults.standard.set(true, forKey: UserPreferences.warningEnabledKey)
            UserDefaults.standard.set(true, forKey: UserPreferences.hapticsEnabledKey)

            #expect(UserPreferences.timerAlertsEnabled == false)
            #expect(UserPreferences.timerWarningEnabled == false)
            #expect(UserPreferences.timerAlertHapticsEnabled == false)
        }
    }

    @Test("TimerPreferences gates warnings and haptics behind master alert setting")
    func timerPreferencesGateAlertsBehindMasterSetting() {
        let prefs = TimerService.TimerPreferences(
            notificationsEnabled: false,
            warningEnabled: true,
            hapticsEnabled: true
        )

        #expect(prefs.timerAlertsEnabled == false)
        #expect(prefs.timerWarningEnabled == false)
        #expect(prefs.timerAlertHapticsEnabled == false)
    }

    @Test(
        "TimerPreferences effective alert settings cover the master-toggle matrix",
        arguments: timerPreferenceExpectations
    )
    func timerPreferencesEffectiveAlertMatrix(expectation: TimerPreferenceExpectation) {
        let prefs = TimerService.TimerPreferences(
            notificationsEnabled: expectation.notificationsEnabled,
            warningEnabled: expectation.warningEnabled,
            hapticsEnabled: expectation.hapticsEnabled
        )

        #expect(prefs.timerAlertsEnabled == expectation.expectedAlerts)
        #expect(prefs.timerWarningEnabled == expectation.expectedWarning)
        #expect(prefs.timerAlertHapticsEnabled == expectation.expectedHaptics)
    }

    @Test(
        "UserPreferences effective alert settings cover the persisted settings matrix",
        .serialized,
        arguments: timerPreferenceExpectations
    )
    func userPreferencesEffectiveAlertMatrix(expectation: TimerPreferenceExpectation) {
        withCleanKeys([
            UserPreferences.notificationsEnabledKey,
            UserPreferences.warningEnabledKey,
            UserPreferences.hapticsEnabledKey
        ]) {
            UserDefaults.standard.set(expectation.notificationsEnabled, forKey: UserPreferences.notificationsEnabledKey)
            UserDefaults.standard.set(expectation.warningEnabled, forKey: UserPreferences.warningEnabledKey)
            UserDefaults.standard.set(expectation.hapticsEnabled, forKey: UserPreferences.hapticsEnabledKey)

            #expect(UserPreferences.notificationsEnabled == expectation.notificationsEnabled)
            #expect(UserPreferences.warningEnabled == expectation.warningEnabled)
            #expect(UserPreferences.hapticsEnabled == expectation.hapticsEnabled)
            #expect(UserPreferences.timerAlertsEnabled == expectation.expectedAlerts)
            #expect(UserPreferences.timerWarningEnabled == expectation.expectedWarning)
            #expect(UserPreferences.timerAlertHapticsEnabled == expectation.expectedHaptics)
        }
    }

    @MainActor
    @Test(
        "Current TimerPreferences preserves raw settings and computes effective settings",
        .serialized,
        arguments: timerPreferenceExpectations
    )
    func currentTimerPreferencesMatrix(expectation: TimerPreferenceExpectation) {
        withCleanKeys([
            UserPreferences.notificationsEnabledKey,
            UserPreferences.warningEnabledKey,
            UserPreferences.hapticsEnabledKey
        ]) {
            UserDefaults.standard.set(expectation.notificationsEnabled, forKey: UserPreferences.notificationsEnabledKey)
            UserDefaults.standard.set(expectation.warningEnabled, forKey: UserPreferences.warningEnabledKey)
            UserDefaults.standard.set(expectation.hapticsEnabled, forKey: UserPreferences.hapticsEnabledKey)

            let prefs = TimerService.TimerPreferences.current()

            #expect(prefs.notificationsEnabled == expectation.notificationsEnabled)
            #expect(prefs.warningEnabled == expectation.warningEnabled)
            #expect(prefs.hapticsEnabled == expectation.hapticsEnabled)
            #expect(prefs.timerAlertsEnabled == expectation.expectedAlerts)
            #expect(prefs.timerWarningEnabled == expectation.expectedWarning)
            #expect(prefs.timerAlertHapticsEnabled == expectation.expectedHaptics)
        }
    }

    @MainActor
    @Test("Current TimerPreferences can override warnings without bypassing master alerts")
    func currentTimerPreferencesWarningOverrideKeepsMasterGate() {
        withCleanKeys([
            UserPreferences.notificationsEnabledKey,
            UserPreferences.warningEnabledKey,
            UserPreferences.hapticsEnabledKey
        ]) {
            UserDefaults.standard.set(true, forKey: UserPreferences.notificationsEnabledKey)
            UserDefaults.standard.set(true, forKey: UserPreferences.warningEnabledKey)
            UserDefaults.standard.set(true, forKey: UserPreferences.hapticsEnabledKey)

            let snoozePrefs = TimerService.TimerPreferences.current(warningEnabled: false)

            #expect(snoozePrefs.notificationsEnabled == true)
            #expect(snoozePrefs.warningEnabled == false)
            #expect(snoozePrefs.hapticsEnabled == true)
            #expect(snoozePrefs.timerAlertsEnabled == true)
            #expect(snoozePrefs.timerWarningEnabled == false)
            #expect(snoozePrefs.timerAlertHapticsEnabled == true)

            UserDefaults.standard.set(false, forKey: UserPreferences.notificationsEnabledKey)

            let alertsOffSnoozePrefs = TimerService.TimerPreferences.current(warningEnabled: false)

            #expect(alertsOffSnoozePrefs.notificationsEnabled == false)
            #expect(alertsOffSnoozePrefs.warningEnabled == false)
            #expect(alertsOffSnoozePrefs.hapticsEnabled == true)
            #expect(alertsOffSnoozePrefs.timerAlertsEnabled == false)
            #expect(alertsOffSnoozePrefs.timerWarningEnabled == false)
            #expect(alertsOffSnoozePrefs.timerAlertHapticsEnabled == false)
        }
    }

    @Test("TimerPreferences aligns with UserPreferences defaults")
    func timerPreferencesAlignsWithUserPreferences() {
        // When UserDefaults has no stored values, UserPreferences and
        // TimerPreferences() should agree on the defaults.
        withCleanKeys([
            UserPreferences.notificationsEnabledKey,
            UserPreferences.warningEnabledKey,
            UserPreferences.warningModeKey,
            UserPreferences.hapticsEnabledKey
        ]) {
            let defaults = TimerService.TimerPreferences()
            #expect(defaults.notificationsEnabled == UserPreferences.notificationsEnabled)
            #expect(defaults.warningEnabled == UserPreferences.warningEnabled)
            #expect(defaults.warningMode == UserPreferences.warningMode)
            #expect(defaults.hapticsEnabled == UserPreferences.hapticsEnabled)
        }
    }

    // MARK: - Helpers

    private func withCleanKey(_ key: String, _ body: () -> Void) {
        let saved = UserDefaults.standard.object(forKey: key)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults.standard.removeObject(forKey: key)
        body()
    }

    private func withCleanKeys(_ keys: [String], _ body: () -> Void) {
        let saved = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        defer {
            for (key, val) in saved {
                if let val { UserDefaults.standard.set(val, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }
        body()
    }
}
