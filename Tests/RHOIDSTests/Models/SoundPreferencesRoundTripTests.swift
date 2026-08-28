import Testing
import Foundation
@testable import RHOIDS

struct SoundPreferencesRoundTripTests {

    // MARK: - Alarm sound persistence

    @Test("Alarm sound defaults to systemDefault")
    func alarmSoundDefault() {
        #expect(type(of: SoundPreferences.alarm) == AlarmSound.self)
    }

    @Test("Every AlarmSound case has a non-empty displayName",
          arguments: AlarmSound.allCases)
    func displayNameNonEmpty(sound: AlarmSound) {
        #expect(sound.displayName.isEmpty == false)
    }

    @Test("Every AlarmSound case has a non-empty subtitle",
          arguments: AlarmSound.allCases)
    func subtitleNonEmpty(sound: AlarmSound) {
        #expect(sound.subtitle.isEmpty == false)
    }

    @Test("Every AlarmSound case has a non-empty symbol",
          arguments: AlarmSound.allCases)
    func symbolNonEmpty(sound: AlarmSound) {
        #expect(sound.symbol.isEmpty == false)
    }

    @Test("Every AlarmSound case has a category",
          arguments: AlarmSound.allCases)
    func categoryNonNil(sound: AlarmSound) {
        let category = sound.category
        #expect(SoundCategory.allCases.contains(category))
    }

    // MARK: - bundledFileName mapping

    @Test("System sounds have nil bundledFileName",
          arguments: [AlarmSound.systemDefault, .systemRingtone])
    func systemSoundsNoBundledFile(sound: AlarmSound) {
        #expect(sound.bundledFileName == nil)
    }

    @Test("Bundled sounds have .caf file names",
          arguments: AlarmSound.allCases.filter { $0.bundledFileName != nil })
    func bundledSoundsHaveCafExtension(sound: AlarmSound) throws {
        let fileName = try #require(sound.bundledFileName,
                                    "\(sound.rawValue) should have a bundled file name")
        #expect(fileName.hasSuffix(".caf"),
                "\(sound.rawValue) should have a .caf file extension")
        #expect(fileName.count > 4, "File name should not be just '.caf'")
    }

    @Test("All bundled file names are unique")
    func bundledFileNamesUnique() {
        let names = AlarmSound.allCases.compactMap(\.bundledFileName)
        #expect(Set(names).count == names.count,
                "Duplicate file names would cause one sound to overwrite another")
    }

    // MARK: - SoundCategory integrity

    @Test("All SoundCategory cases have unique display names")
    func categoryDisplayNamesUnique() {
        let names = SoundCategory.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test("Every SoundCategory has a non-empty display name",
          arguments: SoundCategory.allCases)
    func categoryDisplayName(category: SoundCategory) {
        #expect(category.displayName.isEmpty == false)
    }

    @Test("SoundCategory uses rawValue as ID",
          arguments: SoundCategory.allCases)
    func categoryUsesRawValueAsID(category: SoundCategory) {
        #expect(category.id == category.rawValue)
    }

    // MARK: - Every sound belongs to a valid category

    @Test("All sounds are distributed across categories")
    func allSoundsInCategories() {
        for category in SoundCategory.allCases {
            let sounds = AlarmSound.allCases.filter { $0.category == category }
            #expect(sounds.isEmpty == false,
                    "\(category.rawValue) should have at least one sound")
        }
    }

    // MARK: - Codable round-trip

    @Test("AlarmSound survives JSON encode/decode",
          arguments: AlarmSound.allCases)
    func codableRoundTrip(sound: AlarmSound) throws {
        let data = try JSONEncoder().encode(sound)
        let decoded = try JSONDecoder().decode(AlarmSound.self, from: data)
        #expect(decoded == sound)
    }
}
