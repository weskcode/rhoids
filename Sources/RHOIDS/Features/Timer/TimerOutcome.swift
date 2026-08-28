import Foundation

/// What ended the timer. Drives the completion sheet content.
enum TimerOutcome: Identifiable, Sendable {
    case completed(TimerQuip)
    case stoppedEarly(TimerQuip)

    var id: String {
        switch self {
        case .completed(let q): return "completed-\(q.id)"
        case .stoppedEarly(let q): return "stoppedEarly-\(q.id)"
        }
    }

    var title: String {
        switch self {
        case .completed: return String(localized: "TIME’S UP")
        case .stoppedEarly: return String(localized: "STOPPED EARLY")
        }
    }

    var quip: TimerQuip {
        switch self {
        case .completed(let q), .stoppedEarly(let q): return q
        }
    }

    var iconSymbol: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .stoppedEarly: return "hand.thumbsup.fill"
        }
    }

    /// Only natural completion plays the looping alarm. Early stop is the user
    /// intentionally leaving, so we don't need to summon them back.
    var playsAlarm: Bool {
        switch self {
        case .completed: return true
        case .stoppedEarly: return false
        }
    }
}
