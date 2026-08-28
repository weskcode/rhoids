import Testing
import Foundation
@testable import RHOIDS

struct PresetTimerTests {
    @Test func `All presets exist with correct durations`() {
        #expect(PresetTimer.recommended.duration == 180)
        #expect(PresetTimer.maxAllowed.duration == 300)
        #expect(PresetTimer.custom.duration == 0)
    }

    @Test func `All presets are returned in display order`() {
        let names = PresetTimer.all.map(\.name)
        #expect(names == ["Recommended", "Max", "Custom"])
    }

    @Test func `Preset IDs are stable across launches`() {
        #expect(PresetTimer.recommended.id.uuidString == "A1B2C3D4-0002-0000-0000-000000000002")
        #expect(PresetTimer.maxAllowed.id.uuidString == "A1B2C3D4-0003-0000-0000-000000000003")
        #expect(PresetTimer.custom.id.uuidString == "A1B2C3D4-0004-0000-0000-000000000004")
    }

    @Test func `Recommended is marked as recommended`() {
        #expect(PresetTimer.recommended.isRecommended == true)
        #expect(PresetTimer.maxAllowed.isRecommended == false)
        #expect(PresetTimer.custom.isRecommended == false)
    }

    @Test func `Formatted durations display correctly`() {
        #expect(PresetTimer.recommended.formattedDuration == "3 min")
        #expect(PresetTimer.maxAllowed.formattedDuration == "5 min")
    }

    @Test func `Custom preset has variable duration`() {
        #expect(PresetTimer.custom.duration == 0)
        #expect(PresetTimer.custom.formattedDuration == "0 sec")
    }

    @Test func `isCustom is true only for the custom preset`() {
        #expect(PresetTimer.custom.isCustom == true)
        #expect(PresetTimer.recommended.isCustom == false)
        #expect(PresetTimer.maxAllowed.isCustom == false)
    }

    @Test func `isCustom uses ID not name for identity`() {
        // A preset with the name "Custom" but a different ID should NOT be custom
        let imposter = PresetTimer(
            id: UUID(),
            name: "Custom",
            duration: 0,
            subtitle: "Fake",
            systemImage: "xmark",
            isRecommended: false
        )
        #expect(imposter.isCustom == false,
                "isCustom must compare by stable ID, not display name")
    }

    @Test func `Presets conform to Hashable`() {
        let set = Set(PresetTimer.all)
        #expect(set.count == PresetTimer.all.count)
    }

    @Test func `Presets are sendable`() async {
        let preset = PresetTimer.recommended
        await Task.detached {
            let name = preset.name
            #expect(name == "Recommended")
        }.value
    }
}
