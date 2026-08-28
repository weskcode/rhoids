import Testing
import Foundation
import DeviceActivity
import ManagedSettings
@testable import RHOIDS

struct FocusLockConsistencyTests {

    // MARK: - Cross-target constant consistency
    //
    // FocusLockMonitor (Device Activity extension) uses hardcoded strings
    // because it cannot import the main app target. These tests catch drift
    // between the shared constants and the values the extension depends on.

    @Test func `Suite name matches the value FocusLockMonitor expects`() {
        #expect(SharedStateKeys.suiteName == "group.com.wesley.RHOIDS",
                "FocusLockMonitor hardcodes this suite name - changing it would break cooldown cleanup")
    }

    @Test func `shieldsActive key matches the value FocusLockMonitor writes`() {
        #expect(FocusLockPreferences.shieldsActiveKey == "focusLockShieldsActive",
                "FocusLockMonitor hardcodes this key - changing it would leave shields stuck on after cooldown expires")
    }

    @Test func `DeviceActivity name matches the value FocusLockMonitor listens for`() {
        #expect(DeviceActivityName.focusLockCooldown.rawValue == "com.wesley.RHOIDS.focusLockCooldown",
                "FocusLockMonitor uses a private extension with this exact raw value")
    }

    @Test func `Bathroom session DeviceActivity name matches the value FocusLockMonitor listens for`() {
        #expect(DeviceActivityName.focusLockBathroomSession.rawValue == "com.wesley.RHOIDS.focusLockBathroomSession",
                "FocusLockMonitor uses a private extension with this exact raw value to apply the shield at timer end")
    }

    @Test func `ManagedSettingsStore name matches the value FocusLockMonitor clears`() {
        #expect(ManagedSettingsStore.Name.focusLock.rawValue == "com.wesley.RHOIDS.focusLock",
                "FocusLockMonitor creates a store with this exact name to clear shields")
    }

    @Test func `Mode key matches the value FocusLockMonitor reads`() {
        #expect(FocusLockPreferences.modeKey == "focusLockMode",
                "FocusLockMonitor hardcodes this key to decide whether to apply the shield")
    }

    @Test func `Limited Scrolling raw value matches the value FocusLockMonitor checks`() {
        #expect(FocusLockMode.limitedScrolling.rawValue == "limitedScrolling",
                "FocusLockMonitor hardcodes this raw value - changing it would silently stop app blocking")
    }

    @Test func `Selection key matches the value FocusLockMonitor decodes`() {
        #expect(FocusLockPreferences.selectionKey == "focusLockSelection",
                "FocusLockMonitor hardcodes this key to decode the saved FamilyActivitySelection")
    }

    @Test func `Enabled key matches the value FocusLockMonitor checks`() {
        #expect(FocusLockPreferences.enabledKey == "focusLockEnabled",
                "FocusLockMonitor hardcodes this key to guard shield application")
    }

    @Test func `Bathroom session intent key matches the value FocusLockMonitor checks`() {
        #expect(
            FocusLockPreferences.bathroomSessionShouldShieldKey
                == "focusLockBathroomSessionShouldShield",
            "FocusLockMonitor hardcodes this key to distinguish completion from cancellation"
        )
    }

    // MARK: - Cooldown duration consistency

    static let supportedCooldowns: [TimeInterval] = [300, 600, 900, 1800]

    @Test func `Default cooldown is one of the supported picker values`() {
        #expect(Self.supportedCooldowns.contains(FocusLockPreferences.defaultCooldownDuration),
                "Default cooldown must appear in the settings Picker")
    }

    @Test func `Supported cooldown durations are all positive`() {
        for duration in Self.supportedCooldowns {
            #expect(duration > 0, "Cooldown duration \(duration) must be positive")
        }
    }

    @Test func `Supported cooldown durations are distinct`() {
        #expect(Set(Self.supportedCooldowns).count == Self.supportedCooldowns.count,
                "Duplicate cooldown values would create confusing Picker entries")
    }

    @Test func `Supported cooldown durations are in ascending order`() {
        for i in 1..<Self.supportedCooldowns.count {
            #expect(Self.supportedCooldowns[i] > Self.supportedCooldowns[i - 1],
                    "\(Self.supportedCooldowns[i]) should be greater than \(Self.supportedCooldowns[i - 1])")
        }
    }

    @Test(arguments: supportedCooldowns)
    func `Each supported cooldown round-trips through preferences`(duration: TimeInterval) {
        // Isolated suite per test - no shared App Group state to save/restore.
        let prefs = FocusLockPreferences(suiteName: "test-focuslock-consistency-\(UUID().uuidString)")
        prefs.cooldownDuration = duration
        #expect(prefs.cooldownDuration == duration)
    }

    // MARK: - Preference key isolation

    @Test func `Focus Lock keys do not collide with SharedStateKeys`() {
        let sharedKeys: Set<String> = [
            SharedStateKeys.timerEndDate,
            SharedStateKeys.timerIsRunning,
            SharedStateKeys.timerPresetName,
            SharedStateKeys.timerDuration,
        ]
        let focusLockKeys: Set<String> = [
            FocusLockPreferences.enabledKey,
            FocusLockPreferences.selectionKey,
            FocusLockPreferences.cooldownDurationKey,
            FocusLockPreferences.cooldownEndDateKey,
            FocusLockPreferences.bathroomSessionShouldShieldKey,
            FocusLockPreferences.shieldsActiveKey,
            FocusLockPreferences.modeKey,
        ]
        let overlap = sharedKeys.intersection(focusLockKeys)
        #expect(overlap.isEmpty,
                "Focus Lock keys must not collide with timer state keys: \(overlap)")
    }

    @Test func `Five minute cooldown uses a fifteen minute interval and ten minute warning`() {
        let plan = FocusLockActivitySchedule.make(
            startingAt: Date.now.addingTimeInterval(60),
            duration: 5 * 60
        )

        #expect(plan.usesEndWarning)
        #expect(plan.monitoringDuration == 15 * 60)
        #expect(plan.endWarningOffset == TimeInterval(10 * 60))
    }

    @Test func `Fifteen minute cooldown unlocks at interval end`() {
        let plan = FocusLockActivitySchedule.make(
            startingAt: Date.now.addingTimeInterval(60),
            duration: 15 * 60
        )

        #expect(plan.usesEndWarning == false)
        #expect(plan.monitoringDuration == 15 * 60)
        #expect(plan.endWarningOffset == nil)
    }

    @Test(arguments: [300.0, 600.0, 900.0, 1_800.0])
    func `Every supported cooldown produces a valid future interval`(duration: TimeInterval) {
        let plan = FocusLockActivitySchedule.make(
            startingAt: Date.now.addingTimeInterval(60),
            duration: duration
        )

        let interval = plan.schedule.nextInterval
        #expect(interval != nil)
        #expect(interval?.duration == plan.monitoringDuration)
    }

    @Test func `Nonpositive duration is clamped to a valid short interval`() {
        let plan = FocusLockActivitySchedule.make(
            startingAt: Date.now.addingTimeInterval(60),
            duration: 0
        )

        #expect(plan.monitoringDuration == 15 * 60)
        #expect(plan.endWarningOffset == TimeInterval(15 * 60 - 1))
    }
}
