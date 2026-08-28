import Foundation

struct PresetTimer: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let duration: TimeInterval
    let subtitle: String
    let systemImage: String
    let isRecommended: Bool

    static let recommended = PresetTimer(
        id: UUID(uuidString: "A1B2C3D4-0002-0000-0000-000000000002")!,
        name: String(localized: "Recommended"),
        duration: 180,
        subtitle: String(localized: "Clinically recommended"),
        systemImage: "checkmark.seal",
        isRecommended: true
    )

    static let maxAllowed = PresetTimer(
        id: UUID(uuidString: "A1B2C3D4-0003-0000-0000-000000000003")!,
        name: String(localized: "Max"),
        duration: 300,
        subtitle: String(localized: "Hard limit"),
        systemImage: "exclamationmark.triangle",
        isRecommended: false
    )

    static let custom = PresetTimer(
        id: UUID(uuidString: "A1B2C3D4-0004-0000-0000-000000000004")!,
        name: String(localized: "Custom"),
        duration: 0,
        subtitle: String(localized: "Set your own"),
        systemImage: "slider.horizontal.3",
        isRecommended: false
    )

    static let all: [PresetTimer] = [recommended, maxAllowed, custom]

    /// Identity-safe check - never compare `.name == "Custom"`.
    var isCustom: Bool { id == Self.custom.id }

    var formattedDuration: String {
        DurationFormatter.formatted(duration)
    }
}
