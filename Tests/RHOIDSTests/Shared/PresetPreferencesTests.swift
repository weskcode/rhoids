import Testing
import Foundation
@testable import RHOIDS

struct PresetPreferencesTests {
    /// Save and restore production data around each test.
    private func withCleanPreset(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults(suiteName: SharedStateKeys.suiteName)
        let saved = defaults?.string(forKey: PresetPreferences.defaultPresetKey)
        defer {
            if let saved {
                defaults?.set(saved, forKey: PresetPreferences.defaultPresetKey)
            } else {
                defaults?.removeObject(forKey: PresetPreferences.defaultPresetKey)
            }
        }
        try body()
    }

    @Test func `Default preset is recommended when nothing is stored`() {
        withCleanPreset {
            let defaults = UserDefaults(suiteName: SharedStateKeys.suiteName)
            defaults?.removeObject(forKey: PresetPreferences.defaultPresetKey)
            #expect(PresetPreferences.defaultPreset == .recommended)
        }
    }

    @Test func `Setting and reading default preset round-trips`() {
        withCleanPreset {
            PresetPreferences.defaultPreset = .maxAllowed
            #expect(PresetPreferences.defaultPreset == .maxAllowed)
        }
    }

    @Test func `Unknown stored ID falls back to recommended`() {
        withCleanPreset {
            let defaults = UserDefaults(suiteName: SharedStateKeys.suiteName)
            defaults?.set("00000000-DEAD-BEEF-0000-000000000000", forKey: PresetPreferences.defaultPresetKey)
            #expect(PresetPreferences.defaultPreset == .recommended,
                    "Unknown ID must fall back to .recommended")
        }
    }

    @Test(arguments: PresetTimer.all)
    func `All known presets survive storage round-trip`(preset: PresetTimer) {
        withCleanPreset {
            PresetPreferences.defaultPreset = preset
            #expect(PresetPreferences.defaultPreset == preset,
                    "\(preset.name) should survive round-trip through PresetPreferences")
        }
    }
}
