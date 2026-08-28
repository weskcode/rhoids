import AppIntents
import Foundation

struct TimerPresetEntity: AppEntity {
    static let defaultQuery = TimerPresetQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Timer Preset")

    var id: String
    var name: String
    var duration: TimeInterval

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(Int(duration)/60) min"
        )
    }

    static var all: [TimerPresetEntity] {
        PresetTimer.all.map {
            TimerPresetEntity(
                id: $0.id.uuidString,
                name: $0.name,
                duration: $0.duration
            )
        }
    }
}

struct TimerPresetQuery: EntityQuery {
    func entities(for identifiers: [TimerPresetEntity.ID]) async throws -> [TimerPresetEntity] {
        TimerPresetEntity.all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [TimerPresetEntity] {
        TimerPresetEntity.all
    }

    func defaultResult() async -> TimerPresetEntity? {
        TimerPresetEntity.all.first { $0.id == PresetTimer.recommended.id.uuidString }
    }
}
