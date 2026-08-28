import Foundation
import Testing
@testable import RHOIDS

struct PresetTimerContractTests {

    // MARK: - Identity stability (prevents regression from UUID changes)

    @Test("Recommended preset has stable UUID")
    func recommendedUUIDStable() throws {
        let expectedID = try #require(UUID(uuidString: "A1B2C3D4-0002-0000-0000-000000000002"))
        #expect(PresetTimer.recommended.id == expectedID,
                "Changing this UUID breaks saved user preferences and synced Watch state")
    }

    @Test("MaxAllowed preset has stable UUID")
    func maxAllowedUUIDStable() throws {
        let expectedID = try #require(UUID(uuidString: "A1B2C3D4-0003-0000-0000-000000000003"))
        #expect(PresetTimer.maxAllowed.id == expectedID,
                "Changing this UUID breaks saved user preferences")
    }

    @Test("Custom preset has stable UUID")
    func customUUIDStable() throws {
        let expectedID = try #require(UUID(uuidString: "A1B2C3D4-0004-0000-0000-000000000004"))
        #expect(PresetTimer.custom.id == expectedID,
                "Changing this UUID breaks saved user preferences")
    }

    // MARK: - All presets collection contract

    @Test("PresetTimer.all contains exactly 3 presets")
    func allContainsThreePresets() {
        #expect(PresetTimer.all.count == 3)
    }

    @Test("PresetTimer.all contains recommended, maxAllowed, and custom")
    func allContainsExpectedPresets() {
        #expect(PresetTimer.all.contains(.recommended))
        #expect(PresetTimer.all.contains(.maxAllowed))
        #expect(PresetTimer.all.contains(.custom))
    }

    @Test("All presets have unique IDs")
    func allPresetsHaveUniqueIDs() {
        let ids = PresetTimer.all.map(\.id)
        #expect(Set(ids).count == ids.count, "Duplicate preset IDs would break identity")
    }

    @Test("All presets have unique names")
    func allPresetsHaveUniqueNames() {
        let names = PresetTimer.all.map(\.name)
        #expect(Set(names).count == names.count, "Duplicate names would confuse users")
    }

    // MARK: - isCustom identity check

    @Test("isCustom is true only for the custom preset")
    func isCustomOnlyForCustom() {
        #expect(PresetTimer.custom.isCustom == true)
        #expect(PresetTimer.recommended.isCustom == false)
        #expect(PresetTimer.maxAllowed.isCustom == false)
    }

    @Test("isCustom uses ID comparison, not name comparison")
    func isCustomUsesID() {
        let imposter = PresetTimer(
            id: UUID(),
            name: "Custom",
            duration: 0,
            subtitle: "Fake",
            systemImage: "slider.horizontal.3",
            isRecommended: false
        )
        #expect(imposter.isCustom == false,
                "isCustom should match by ID, not by name")
    }

    // MARK: - Duration sanity

    @Test("Recommended duration is 3 minutes (180s)")
    func recommendedDuration() {
        #expect(PresetTimer.recommended.duration == 180)
    }

    @Test("MaxAllowed duration is 5 minutes (300s)")
    func maxAllowedDuration() {
        #expect(PresetTimer.maxAllowed.duration == 300)
    }

    @Test("Custom preset has 0 duration (placeholder)")
    func customDurationIsZero() {
        #expect(PresetTimer.custom.duration == 0,
                "Custom preset duration is a placeholder - actual duration comes from customDuration")
    }

    @Test("No preset exceeds the medical safety threshold of 5 minutes")
    func noPresetExceedsSafetyThreshold() {
        for preset in PresetTimer.all where !preset.isCustom {
            #expect(preset.duration <= 300,
                    "Preset '\(preset.name)' at \(preset.duration)s exceeds the 5-minute safety limit")
        }
    }

    @Test("Only recommended preset is marked isRecommended")
    func onlyRecommendedIsRecommended() {
        let recommended = PresetTimer.all.filter(\.isRecommended)
        #expect(recommended.count == 1)
        #expect(recommended.first == .recommended)
    }

    // MARK: - Hashable contract

    @Test("PresetTimer Hashable is consistent with Equatable")
    func hashableConsistency() {
        let a = PresetTimer.recommended
        let b = PresetTimer.recommended
        #expect(a == b)
        #expect(a.hashValue == b.hashValue,
                "Equal values must have equal hash values")
    }

    @Test("Different presets have different hash values")
    func differentPresetsHash() {
        let hashes = Set(PresetTimer.all.map(\.hashValue))
        #expect(hashes.count == PresetTimer.all.count,
                "All presets should produce distinct hashes (probabilistically)")
    }

    // MARK: - formattedDuration integration

    @Test("Every non-custom preset formats to a clean minute string")
    func nonCustomPresetsFormatCleanly() {
        for preset in PresetTimer.all where !preset.isCustom {
            let formatted = preset.formattedDuration
            #expect(formatted.hasSuffix("min"),
                    "'\(preset.name)' formatted as '\(formatted)' - expected 'N min'")
        }
    }

    // MARK: - Lookup by name (used in adoptSharedStateIfNeeded)

    @Test("Every preset can be looked up by name from PresetTimer.all")
    func lookupByName() {
        for preset in PresetTimer.all {
            let found = PresetTimer.all.first { $0.name == preset.name }
            #expect(found == preset)
        }
    }

    @Test("Unknown preset name falls back gracefully")
    func unknownNameFallback() {
        let found = PresetTimer.all.first { $0.name == "NonexistentPreset" } ?? .recommended
        #expect(found == .recommended,
                "Unknown preset name should fall back to recommended")
    }
}
