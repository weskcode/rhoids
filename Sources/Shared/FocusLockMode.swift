import Foundation

/// Which bathroom-focus experience the user picked, in onboarding or Settings.
enum FocusLockMode: String, CaseIterable, Codable, Sendable {
    /// "I want to not be on my phone at all." No Screen Time shielding -     /// just a reminder to put the phone down.
    case phoneFree
    /// "Let me use a few apps, then block them when time's up." Backed by
    /// Screen Time: apps are allowed during the timer, shielded at
    /// completion, and unshielded after the cooldown.
    case limitedScrolling
}

extension FocusLockMode {
    struct NotificationCopy: Sendable {
        let title: String
        let body: String
    }

    /// A reminder fired near the start of the timer. Only `.phoneFree` needs
    /// one - `.limitedScrolling` users are expected to use their phone.
    var startReminder: NotificationCopy? {
        switch self {
        case .phoneFree:
            return NotificationCopy(
                title: String(localized: "PUT YOUR PHONE DOWN!"),
                body: String(localized: "This is a phone-free bathroom break. Set it down. We'll let you know when time's up.")
            )
        case .limitedScrolling:
            return nil
        }
    }

    /// Copy for the timer-completion alert (AlarmKit title + fallback
    /// notification title/body).
    func completionCopy(cooldownMinutes: Int) -> NotificationCopy {
        switch self {
        case .phoneFree:
            return NotificationCopy(
                title: String(localized: "Time's Up!"),
                body: String(localized: "Nice work staying off your phone. Stand up and walk away.")
            )
        case .limitedScrolling:
            return NotificationCopy(
                title: String(localized: "Apps Locked"),
                body: String(localized: "Time's up. Your apps are blocked for the next \(cooldownMinutes) min.")
            )
        }
    }

    /// Title for the AlarmKit full-screen alert.
    func alarmKitTitle(cooldownMinutes: Int) -> String {
        completionCopy(cooldownMinutes: cooldownMinutes).title
    }

    /// Resolves the mode that should actually drive completion messaging for
    /// a timer run. `.limitedScrolling` only "counts" if blocking will really
    /// engage (authorized + apps picked) - otherwise callers should fall back
    /// to a neutral default rather than falsely claiming apps are blocked.
    static func effective(selected: FocusLockMode, blockingWillEngage: Bool) -> FocusLockMode? {
        switch selected {
        case .phoneFree:
            return .phoneFree
        case .limitedScrolling:
            return blockingWillEngage ? .limitedScrolling : nil
        }
    }
}
