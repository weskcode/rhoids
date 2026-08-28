import Testing
import Foundation
import AppIntents
@testable import RHOIDS

struct IntentEntityTests {

    // MARK: - TimerPresetEntity catalog

    @Test("TimerPresetEntity.all has the same count as PresetTimer.all")
    func entityCountMatchesPresets() {
        #expect(TimerPresetEntity.all.count == PresetTimer.all.count)
    }

    @Test("Every entity ID maps back to a valid PresetTimer")
    func entityIDsMappable() {
        for entity in TimerPresetEntity.all {
            let match = PresetTimer.all.first { $0.id.uuidString == entity.id }
            #expect(match != nil, "Entity '\(entity.name)' should map to a PresetTimer")
        }
    }

    @Test("Entity names match PresetTimer names")
    func entityNamesMatchPresets() {
        for entity in TimerPresetEntity.all {
            let preset = PresetTimer.all.first { $0.id.uuidString == entity.id }
            #expect(entity.name == preset?.name,
                    "Entity name '\(entity.name)' should match preset name '\(preset?.name ?? "nil")'")
        }
    }

    @Test("Entity durations match PresetTimer durations")
    func entityDurationsMatchPresets() {
        for entity in TimerPresetEntity.all {
            let preset = PresetTimer.all.first { $0.id.uuidString == entity.id }
            #expect(entity.duration == preset?.duration,
                    "\(entity.name) duration mismatch")
        }
    }

    @Test("All entity IDs are unique")
    func entityIDsUnique() {
        let ids = TimerPresetEntity.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    // MARK: - Display representation

    @Test("displayRepresentation subtitle contains duration for every entity",
          arguments: TimerPresetEntity.all)
    func displayRepresentationExists(entity: TimerPresetEntity) {
        let display = entity.displayRepresentation
        #expect(display.subtitle != nil,
                "Entity '\(entity.name)' should have a subtitle with its duration")
    }

    // MARK: - TimerPresetQuery

    @Test("suggestedEntities returns all presets")
    func suggestedEntitiesReturnsAll() async throws {
        let query = TimerPresetQuery()
        let suggestions = try await query.suggestedEntities()
        #expect(suggestions.count == PresetTimer.all.count)
    }

    @Test("defaultResult returns the recommended preset")
    func defaultResultIsRecommended() async throws {
        let query = TimerPresetQuery()
        let result = try #require(await query.defaultResult())
        #expect(result.id == PresetTimer.recommended.id.uuidString)
    }

    @Test("entities(for:) filters by identifier")
    func entitiesForIdentifiers() async throws {
        let query = TimerPresetQuery()
        let targetID = PresetTimer.maxAllowed.id.uuidString
        let results = try await query.entities(for: [targetID])
        #expect(results.count == 1)
        #expect(results.first?.id == targetID)
    }

    @Test("entities(for:) returns empty for unknown IDs")
    func entitiesForUnknownIDs() async throws {
        let query = TimerPresetQuery()
        let results = try await query.entities(for: ["not-a-real-id"])
        #expect(results.isEmpty)
    }

    // MARK: - Intent type display representation

    @Test("TimerPresetEntity type display representation has the expected name")
    func typeDisplayRepresentationExists() {
        let rep = TimerPresetEntity.typeDisplayRepresentation
        #expect("\(rep.name.key)" == "Timer Preset",
                "Type display representation name should be 'Timer Preset'")
    }
}
