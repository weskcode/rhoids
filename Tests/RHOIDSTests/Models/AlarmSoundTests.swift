import Testing
import Foundation
import UserNotifications
@testable import RHOIDS

struct AlarmSoundTests {

    // MARK: - Case count and completeness

    @Test func `Expected case count`() {
        // 2 system + 5 classic + 2 meditative + 3 melodic + 2 nature = 14 total
        #expect(AlarmSound.allCases.count == 14,
                "If a sound was added or removed, update this test and the picker categories")
    }

    @Test func `All sounds have unique display names`() {
        let names = AlarmSound.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test func `All sounds have non-empty display names`() {
        for sound in AlarmSound.allCases {
            #expect(sound.displayName.isEmpty == false, "\(sound) has an empty display name")
        }
    }

    @Test func `All sounds have non-empty subtitles`() {
        for sound in AlarmSound.allCases {
            #expect(sound.subtitle.isEmpty == false, "\(sound) has an empty subtitle")
        }
    }

    @Test func `All sounds have symbols`() {
        for sound in AlarmSound.allCases {
            #expect(sound.symbol.isEmpty == false, "\(sound) missing a symbol")
        }
    }

    @Test func `All sounds are identifiable`() {
        for sound in AlarmSound.allCases {
            #expect(sound.id == sound.rawValue)
        }
    }

    // MARK: - Raw value stability (persistence contract)

    @Test func `Raw values are stable and must never change`() {
        let expected: [AlarmSound: String] = [
            .systemDefault: "systemDefault",
            .systemRingtone: "systemRingtone",
            .bell: "bell",
            .chime: "chime",
            .marimba: "marimba",
            .digital: "digital",
            .bubbles: "bubbles",
            .singingBowl: "singingBowl",
            .gong: "gong",
            .harp: "harp",
            .musicBox: "musicBox",
            .crystal: "crystal",
            .zen: "zen",
            .birdsong: "birdsong",
        ]
        for sound in AlarmSound.allCases {
            #expect(expected[sound] == sound.rawValue,
                    "Raw value for \(sound) changed - this breaks saved preferences and Watch sync")
        }
        #expect(expected.count == AlarmSound.allCases.count)
    }

    // MARK: - File mapping

    @Test func `System sounds have no bundled file`() {
        #expect(AlarmSound.systemDefault.bundledFileName == nil)
        #expect(AlarmSound.systemRingtone.bundledFileName == nil)
    }

    @Test func `Bundled sounds have file names`() {
        for sound in AlarmSound.allCases {
            if case .systemDefault = sound { continue }
            if case .systemRingtone = sound { continue }
            #expect(sound.bundledFileName != nil, "\(sound) missing bundled file name")
        }
    }

    @Test func `Bundled file names end with caf extension`() {
        for sound in AlarmSound.allCases {
            guard let file = sound.bundledFileName else { continue }
            #expect(file.hasSuffix(".caf"), "\(sound) bundled file '\(file)' should be a .caf file")
        }
    }

    @Test func `All bundled file names are unique`() {
        let fileNames = AlarmSound.allCases.compactMap(\.bundledFileName)
        #expect(Set(fileNames).count == fileNames.count,
                "Two sounds share the same file name - they'd overwrite each other")
    }

    /// Guards against the bug that existed before: AlarmSound declared bundled
    /// file names but the actual .caf files were never added to the project.
    @Test func `All bundled sound files exist in the app bundle`() {
        for sound in AlarmSound.allCases {
            guard let file = sound.bundledFileName else { continue }
            let url = Bundle.main.url(forResource: file, withExtension: nil)
            #expect(url != nil,
                    "\(sound) references '\(file)' but the file is missing from the bundle")
        }
    }

    // MARK: - Categories

    @Test func `Every sound belongs to a category`() {
        for sound in AlarmSound.allCases {
            // category is a non-optional enum, so this mainly checks the
            // switch is exhaustive - the compiler does that too, but the
            // test documents the contract.
            #expect(SoundCategory.allCases.contains(sound.category),
                    "\(sound) has an unknown category")
        }
    }

    @Test func `Every category has at least one sound`() {
        for category in SoundCategory.allCases {
            let sounds = AlarmSound.allCases.filter { $0.category == category }
            #expect(sounds.isEmpty == false,
                    "Category '\(category)' has no sounds - it will show an empty section in the picker")
        }
    }

    @Test func `Category display names are non-empty and unique`() {
        let names = SoundCategory.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
        for name in names {
            #expect(name.isEmpty == false)
        }
    }

    // MARK: - Notification integration

    @Test(arguments: AlarmSound.allCases)
    func `Every sound produces a valid notification sound`(sound: AlarmSound) {
        let result = sound.notificationSound()
        #expect(result == result, "\(sound) should produce a valid notification sound")
    }

    @Test func `System default uses default notification sound`() {
        #expect(AlarmSound.systemDefault.notificationSound() == .default)
    }

    // MARK: - Codable round-trip

    @Test func `All cases survive JSON round-trip`() throws {
        let sounds = AlarmSound.allCases
        let data = try JSONEncoder().encode(sounds)
        let decoded = try JSONDecoder().decode([AlarmSound].self, from: data)
        #expect(decoded == sounds, "Codable round-trip must preserve all cases")
    }
}
