import Testing
import Foundation
@testable import RHOIDS

/// Tests for the SoundPreferences type.
///
/// Note: SoundPreferences reads/writes from the production App Group via
/// static properties. To avoid corrupting real user data we save and restore
/// the original values around each mutating test.
struct SoundPreferencesTests {
    private static let productionSuite = SharedStateKeys.suiteName
    private static let alarmKey = "alarmSound.v1"
    private static let warningKey = "warningSound.v1"

    /// Snapshot + restore helper so we never leave production data dirty.
    private func withCleanPreferences(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults(suiteName: Self.productionSuite)
        let savedAlarm = defaults?.string(forKey: Self.alarmKey)
        let savedWarning = defaults?.string(forKey: Self.warningKey)
        defer {
            if let savedAlarm {
                defaults?.set(savedAlarm, forKey: Self.alarmKey)
            } else {
                defaults?.removeObject(forKey: Self.alarmKey)
            }
            if let savedWarning {
                defaults?.set(savedWarning, forKey: Self.warningKey)
            } else {
                defaults?.removeObject(forKey: Self.warningKey)
            }
        }
        try body()
    }

    @Test func `Fresh defaults return systemDefault for alarm`() {
        withCleanPreferences {
            let defaults = UserDefaults(suiteName: Self.productionSuite)
            defaults?.removeObject(forKey: Self.alarmKey)
            #expect(SoundPreferences.alarm == .systemDefault)
        }
    }

    @Test func `Fresh defaults return systemDefault for warning`() {
        withCleanPreferences {
            let defaults = UserDefaults(suiteName: Self.productionSuite)
            defaults?.removeObject(forKey: Self.warningKey)
            #expect(SoundPreferences.warning == .systemDefault)
        }
    }

    @Test func `Can store and retrieve alarm sound`() {
        withCleanPreferences {
            SoundPreferences.alarm = .marimba
            #expect(SoundPreferences.alarm == .marimba)
        }
    }

    @Test func `Can store and retrieve warning sound`() {
        withCleanPreferences {
            SoundPreferences.warning = .chime
            #expect(SoundPreferences.warning == .chime)
        }
    }

    @Test func `Alarm and warning sounds are stored independently`() {
        withCleanPreferences {
            SoundPreferences.alarm = .bell
            SoundPreferences.warning = .digital

            #expect(SoundPreferences.alarm == .bell, "alarm should be .bell")
            #expect(SoundPreferences.warning == .digital, "warning should be .digital")
        }
    }

    @Test func `Invalid raw value falls back to systemDefault`() {
        withCleanPreferences {
            let defaults = UserDefaults(suiteName: Self.productionSuite)
            defaults?.set("nonexistent_sound", forKey: Self.alarmKey)
            #expect(SoundPreferences.alarm == .systemDefault,
                    "Unknown raw value must fall back to .systemDefault, not crash")
        }
    }

    @Test(arguments: AlarmSound.allCases)
    func `All alarm sounds survive round-trip through preferences`(sound: AlarmSound) {
        withCleanPreferences {
            SoundPreferences.alarm = sound
            #expect(SoundPreferences.alarm == sound,
                    "\(sound) should round-trip through SoundPreferences.alarm")
        }
    }
}
