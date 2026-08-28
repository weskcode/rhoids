import Foundation
import Testing
@testable import RHOIDS

struct AlarmSoundCategoryIntegrityTests {

    // MARK: - Category distribution sanity

    @Test("System category contains exactly 2 sounds")
    func systemCategoryCount() {
        let system = AlarmSound.allCases.filter { $0.category == .system }
        #expect(system.count == 2,
                "System category should have systemDefault and systemRingtone")
    }

    @Test("Classic category contains exactly 5 sounds")
    func classicCategoryCount() {
        let classic = AlarmSound.allCases.filter { $0.category == .classic }
        #expect(classic.count == 5)
    }

    @Test("No category has zero sounds (empty picker section)")
    func noCategoryIsEmpty() {
        for category in SoundCategory.allCases {
            let count = AlarmSound.allCases.filter { $0.category == category }.count
            #expect(count > 0,
                    "'\(category.displayName)' category is empty - would show a blank section in the picker")
        }
    }

    @Test("Sum of all categories equals total sound count")
    func categorySumsMatch() {
        let total = SoundCategory.allCases.reduce(0) { sum, cat in
            sum + AlarmSound.allCases.filter { $0.category == cat }.count
        }
        #expect(total == AlarmSound.allCases.count,
                "Every sound must belong to exactly one category")
    }

    // MARK: - Symbol uniqueness per category

    @Test("No two sounds in the same category share the same SF Symbol")
    func uniqueSymbolsPerCategory() {
        for category in SoundCategory.allCases {
            let sounds = AlarmSound.allCases.filter { $0.category == category }
            let symbols = sounds.map(\.symbol)
            #expect(Set(symbols).count == symbols.count,
                    "Category '\(category.displayName)' has duplicate symbols - confusing in picker")
        }
    }

    // MARK: - SoundPreferences corrupt value resilience

    @Test("SoundPreferences.alarm falls back to systemDefault for unknown raw value")
    func alarmFallbackForUnknownRaw() {
        let suiteName = SharedStateKeys.suiteName
        let defaults = UserDefaults(suiteName: suiteName)
        let key = "alarmSound.v1"
        let saved = defaults?.string(forKey: key)
        defer {
            if let saved { defaults?.set(saved, forKey: key) }
            else { defaults?.removeObject(forKey: key) }
        }

        defaults?.set("deletedSoundFromV1", forKey: key)
        #expect(SoundPreferences.alarm == .systemDefault,
                "Corrupt/legacy raw value should fall back to systemDefault, not crash")
    }

    @Test("SoundPreferences.warning falls back to systemDefault for unknown raw value")
    func warningFallbackForUnknownRaw() {
        let suiteName = SharedStateKeys.suiteName
        let defaults = UserDefaults(suiteName: suiteName)
        let key = "warningSound.v1"
        let saved = defaults?.string(forKey: key)
        defer {
            if let saved { defaults?.set(saved, forKey: key) }
            else { defaults?.removeObject(forKey: key) }
        }

        defaults?.set("nonexistent_sound", forKey: key)
        #expect(SoundPreferences.warning == .systemDefault)
    }

    @Test("SoundPreferences.alarm falls back to systemDefault when key is absent")
    func alarmFallbackWhenAbsent() {
        let suiteName = SharedStateKeys.suiteName
        let defaults = UserDefaults(suiteName: suiteName)
        let key = "alarmSound.v1"
        let saved = defaults?.string(forKey: key)
        defer {
            if let saved { defaults?.set(saved, forKey: key) }
            else { defaults?.removeObject(forKey: key) }
        }

        defaults?.removeObject(forKey: key)
        #expect(SoundPreferences.alarm == .systemDefault)
    }

    // MARK: - SoundPreferences round-trip for every sound

    @Test("Every AlarmSound case survives SoundPreferences write/read round-trip")
    func everyAlarmSoundRoundTrips() {
        let suiteName = SharedStateKeys.suiteName
        let defaults = UserDefaults(suiteName: suiteName)
        let alarmKey = "alarmSound.v1"
        let warningKey = "warningSound.v1"
        let savedAlarm = defaults?.string(forKey: alarmKey)
        let savedWarning = defaults?.string(forKey: warningKey)
        defer {
            if let savedAlarm { defaults?.set(savedAlarm, forKey: alarmKey) }
            else { defaults?.removeObject(forKey: alarmKey) }
            if let savedWarning { defaults?.set(savedWarning, forKey: warningKey) }
            else { defaults?.removeObject(forKey: warningKey) }
        }

        for sound in AlarmSound.allCases {
            SoundPreferences.alarm = sound
            #expect(SoundPreferences.alarm == sound,
                    "\(sound) did not survive alarm round-trip")

            SoundPreferences.warning = sound
            #expect(SoundPreferences.warning == sound,
                    "\(sound) did not survive warning round-trip")
        }
    }
}
