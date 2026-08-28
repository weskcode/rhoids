import Testing
import Foundation
@testable import RHOIDS

struct AlarmPlayerToneTests {

    // MARK: - AlarmKitService key stability

    @Test("AlarmKitService active ID key is stable")
    func activeIDKeyStability() {
        #expect(AlarmKitService.activeIDKey == "activeAlarmKitID",
                "Changing this key would orphan any in-flight alarm on update")
    }

    @Test("AlarmKitService uses SharedStateKeys suite name")
    func alarmKitSuiteName() {
        #expect(AlarmKitService.suiteName == SharedStateKeys.suiteName)
    }

    // MARK: - TimerService.TimerPreferences computed properties

    @Test("timerAlertsEnabled mirrors notificationsEnabled")
    func timerAlertsEnabled() {
        let enabled = TimerService.TimerPreferences(notificationsEnabled: true)
        let disabled = TimerService.TimerPreferences(notificationsEnabled: false)
        #expect(enabled.timerAlertsEnabled == true)
        #expect(disabled.timerAlertsEnabled == false)
    }

    @Test("timerWarningEnabled requires both notifications and warning")
    func timerWarningEnabled() {
        let bothOn = TimerService.TimerPreferences(notificationsEnabled: true, warningEnabled: true)
        let notifOff = TimerService.TimerPreferences(notificationsEnabled: false, warningEnabled: true)
        let warnOff = TimerService.TimerPreferences(notificationsEnabled: true, warningEnabled: false)
        let bothOff = TimerService.TimerPreferences(notificationsEnabled: false, warningEnabled: false)

        #expect(bothOn.timerWarningEnabled == true)
        #expect(notifOff.timerWarningEnabled == false)
        #expect(warnOff.timerWarningEnabled == false)
        #expect(bothOff.timerWarningEnabled == false)
    }

    @Test("timerAlertHapticsEnabled requires both notifications and haptics")
    func timerAlertHapticsEnabled() {
        let bothOn = TimerService.TimerPreferences(notificationsEnabled: true, hapticsEnabled: true)
        let notifOff = TimerService.TimerPreferences(notificationsEnabled: false, hapticsEnabled: true)
        let hapticsOff = TimerService.TimerPreferences(notificationsEnabled: true, hapticsEnabled: false)
        let bothOff = TimerService.TimerPreferences(notificationsEnabled: false, hapticsEnabled: false)

        #expect(bothOn.timerAlertHapticsEnabled == true)
        #expect(notifOff.timerAlertHapticsEnabled == false)
        #expect(hapticsOff.timerAlertHapticsEnabled == false)
        #expect(bothOff.timerAlertHapticsEnabled == false)
    }

    @Test("Default TimerPreferences has all flags enabled")
    func defaultPreferencesAllEnabled() {
        let prefs = TimerService.TimerPreferences()
        #expect(prefs.notificationsEnabled == true)
        #expect(prefs.warningEnabled == true)
        #expect(prefs.hapticsEnabled == true)
        #expect(prefs.warningMode == .endOnly)
        #expect(prefs.alarmSound == .systemDefault)
        #expect(prefs.warningSound == .systemDefault)
    }

    // MARK: - TimerPreferences warning mode combinations

    @Test("endOnly is the default warning mode")
    func defaultWarningMode() {
        let prefs = TimerService.TimerPreferences()
        #expect(prefs.warningMode == .endOnly)
    }

    @Test("recurring warning mode is preserved")
    func recurringWarningMode() {
        let prefs = TimerService.TimerPreferences(warningMode: .recurring)
        #expect(prefs.warningMode == .recurring)
    }
}
