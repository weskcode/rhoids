import Foundation

enum WarningMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case endOnly
    case recurring

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .endOnly: String(localized: "End Only")
        case .recurring: String(localized: "Every 30 Seconds")
        }
    }

    var settingsDescription: String {
        switch self {
        case .endOnly: String(localized: "A gentle reminder 30 seconds before your timer ends.")
        case .recurring: String(localized: "Gentle reminders every 30 seconds to stay relaxed and not rush.")
        }
    }
}
