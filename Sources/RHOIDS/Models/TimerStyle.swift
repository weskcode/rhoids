import Foundation

enum TimerStyle: String, CaseIterable, Identifiable {
    case card
    case ring
    case progress
    case flip
    case dial
    case gauge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .card: String(localized: "Card")
        case .ring: String(localized: "Ring")
        case .progress: String(localized: "Bar")
        case .flip: String(localized: "Flip")
        case .dial: String(localized: "Dial")
        case .gauge: String(localized: "Gauge")
        }
    }

    var description: String {
        switch self {
        case .card: String(localized: "Numeric countdown in a rounded card")
        case .ring: String(localized: "Circular progress ring with countdown")
        case .progress: String(localized: "Horizontal bar that drains as time passes")
        case .flip: String(localized: "Retro split-flap clock with digit tiles")
        case .dial: String(localized: "Kitchen timer with tick marks")
        case .gauge: String(localized: "Segmented meter that drains over time")
        }
    }
}
