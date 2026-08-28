import Testing
import Foundation
@testable import RHOIDS

struct PresetTimerComputedTests {

    // MARK: - isCustom

    @Test("Only the custom preset returns isCustom true")
    func onlyCustomIsCustom() {
        for preset in PresetTimer.all {
            if preset.id == PresetTimer.custom.id {
                #expect(preset.isCustom == true)
            } else {
                #expect(preset.isCustom == false,
                        "\(preset.name) should not be custom")
            }
        }
    }

    @Test("isCustom uses identity, not name comparison")
    func isCustomUsesIdentity() {
        let imposter = PresetTimer(
            id: UUID(),
            name: "Custom",
            duration: 0,
            subtitle: "Fake",
            systemImage: "star",
            isRecommended: false
        )
        #expect(imposter.isCustom == false,
                "isCustom should compare IDs, not names")
    }

    // MARK: - formattedDuration

    @Test("Recommended preset formats as 3 min")
    func recommendedFormattedDuration() {
        #expect(PresetTimer.recommended.formattedDuration == "3 min")
    }

    @Test("Max preset formats as 5 min")
    func maxFormattedDuration() {
        #expect(PresetTimer.maxAllowed.formattedDuration == "5 min")
    }

    @Test("Custom preset with zero duration formats as 0 sec")
    func customFormattedDuration() {
        #expect(PresetTimer.custom.formattedDuration == "0 sec")
    }

    // MARK: - Preset catalog integrity

    @Test("Exactly one preset is recommended")
    func exactlyOneRecommended() {
        let recommended = PresetTimer.all.filter(\.isRecommended)
        #expect(recommended.count == 1)
    }

    @Test("Recommended preset has non-zero duration")
    func recommendedHasNonZeroDuration() {
        #expect(PresetTimer.recommended.duration > 0)
    }

    @Test("All preset IDs are unique")
    func allIDsUnique() {
        let ids = PresetTimer.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("All presets have non-empty name and system image")
    func allPresetsHaveContent() {
        for preset in PresetTimer.all {
            #expect(preset.name.isEmpty == false, "\(preset.id) has empty name")
            #expect(preset.systemImage.isEmpty == false, "\(preset.id) has empty systemImage")
            #expect(preset.subtitle.isEmpty == false, "\(preset.id) has empty subtitle")
        }
    }

    // MARK: - Hashable / Equatable

    @Test("Same preset instance is equal to itself")
    func sameInstanceEquality() {
        let a = PresetTimer.recommended
        let b = PresetTimer.recommended
        #expect(a == b)
    }

    @Test("Different presets are not equal")
    func differentPresetsNotEqual() {
        #expect(PresetTimer.recommended != PresetTimer.maxAllowed)
        #expect(PresetTimer.recommended != PresetTimer.custom)
    }

    @Test("PresetTimer conforms to Hashable for use in sets")
    func hashableConformance() {
        let set: Set<PresetTimer> = [.recommended, .maxAllowed, .custom, .recommended]
        #expect(set.count == 3)
    }
}
