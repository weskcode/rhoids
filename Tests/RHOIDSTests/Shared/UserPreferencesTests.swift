import Testing
import Foundation
@testable import RHOIDS

struct UserPreferencesTests {
    /// A fresh, isolated UserDefaults suite so tests can run in parallel
    /// without touching shared global state.
    private func makeIsolatedDefaults() throws -> (defaults: UserDefaults, cleanup: () -> Void) {
        let suiteName = "test-userprefs-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, { defaults.removePersistentDomain(forName: suiteName) })
    }

    @Test func `Keys are non-empty and unique`() {
        let keys = [
            UserPreferences.notificationsEnabledKey,
            UserPreferences.warningEnabledKey,
            UserPreferences.warningModeKey,
            UserPreferences.hapticsEnabledKey,
            UserPreferences.lastCustomDurationKey,
            UserPreferences.timerStyleKey,
            UserPreferences.appearanceModeKey,
        ]
        #expect(Set(keys).count == keys.count, "All preference keys must be unique")
        for key in keys {
            #expect(key.isEmpty == false, "Preference key must not be empty")
        }
    }

    /// `timerStyleKey` is the on-disk UserDefaults key that every Timer Display
    /// view binds to via `@AppStorage`, and is the key existing users' saved
    /// choice already lives under. Changing its value would silently reset
    /// everyone back to the default, so the string is pinned here.
    @Test func `Timer style key has its expected stored value`() {
        #expect(UserPreferences.timerStyleKey == "timerStyle",
                "The persisted key must stay 'timerStyle' or saved preferences are lost")
    }

    /// The phone writes `timerStyle` through `UserPreferences.timerStyleKey`,
    /// and the Watch-sync layer must read/write the same key for the preference
    /// to cross over. This guards against either side drifting to a literal.
    @Test func `Watch sync uses the same timer style key as the app`() {
        #expect(SyncedPreferences.Keys.timerStyle == UserPreferences.timerStyleKey,
                "Phone and Watch must share one timerStyle key, or sync silently breaks")
    }

    @Test func `Defaults are true when nothing is stored`() throws {
        let (defaults, cleanup) = try makeIsolatedDefaults()
        defer { cleanup() }

        #expect(UserPreferences.notificationsEnabled(in: defaults) == true, "Default should be true")
        #expect(UserPreferences.warningEnabled(in: defaults) == true, "Default should be true")
        #expect(UserPreferences.hapticsEnabled(in: defaults) == true, "Default should be true")
    }

    @Test func `Explicit false overrides default true`() throws {
        let (defaults, cleanup) = try makeIsolatedDefaults()
        defer { cleanup() }

        defaults.set(false, forKey: UserPreferences.notificationsEnabledKey)
        #expect(UserPreferences.notificationsEnabled(in: defaults) == false,
                "Explicitly stored false must override the default true")
    }

    @Test func `Warning mode defaults to endOnly when nothing stored`() throws {
        let (defaults, cleanup) = try makeIsolatedDefaults()
        defer { cleanup() }

        #expect(UserPreferences.warningMode(in: defaults) == .endOnly)
    }

    @Test func `Stored recurring reads correctly`() throws {
        let (defaults, cleanup) = try makeIsolatedDefaults()
        defer { cleanup() }

        defaults.set("recurring", forKey: UserPreferences.warningModeKey)
        #expect(UserPreferences.warningMode(in: defaults) == .recurring)
    }

    @Test func `Invalid warning mode string falls back to endOnly`() throws {
        let (defaults, cleanup) = try makeIsolatedDefaults()
        defer { cleanup() }

        defaults.set("garbage", forKey: UserPreferences.warningModeKey)
        #expect(UserPreferences.warningMode(in: defaults) == .endOnly,
                "Unrecognized raw value must fall back to endOnly")
    }

    @Test func `Warning mode key matches SyncedPreferences key`() {
        #expect(SyncedPreferences.Keys.warningMode == UserPreferences.warningModeKey,
                "Phone and Watch must share one warningMode key")
    }
}
