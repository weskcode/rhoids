import Foundation

/// Pure, value-type schedule for the Watch's 30-second warning haptics
/// (the "reminders" the user selects in Settings).
///
/// This mirrors the cadence of the iPhone `TimerService` beep schedule, but as a
/// standalone value type it can be unit-tested without touching `WKInterfaceDevice`.
/// It walks a single `nextBeepAt` threshold downwards as time elapses, which is
/// both simpler and more correct than tracking a set of "already beeped" boundaries.
///
/// Cadence, given a starting amount of time remaining:
/// - `.endOnly` - a single reminder at T-30 (or at start if the timer is shorter
///   than 30 seconds).
/// - `.recurring` - a reminder at every 30-second boundary *strictly inside* the
///   remaining time, e.g. a fresh 3:00 timer fires at 2:30, 2:00, 1:30, 1:00, 0:30.
///
/// Because the schedule is seeded with the time remaining *at the moment it
/// starts*, it behaves correctly both for fresh timers (`remainingAtStart ==
/// duration`) and for timers adopted mid-run from the iPhone (`remainingAtStart`
/// is whatever is left at adoption). The previous Watch implementation mis-marked
/// boundaries when adopting and could skip - or entirely drop - reminders.
struct WatchWarningSchedule {
    /// The next amount-remaining (in seconds) at which a reminder should fire.
    /// Reaches `0` once no further reminders are due.
    private(set) var nextBeepAt: TimeInterval

    let mode: WarningMode

    /// - Parameters:
    ///   - remainingAtStart: seconds left when the schedule begins. For a fresh
    ///     timer this equals the full duration; for a timer adopted partway
    ///     through, it's the time left at adoption.
    ///   - mode: end-only fires once at T-30; recurring fires at every 30s boundary.
    init(remainingAtStart: TimeInterval, mode: WarningMode) {
        self.mode = mode
        switch mode {
        case .endOnly:
            nextBeepAt = min(30, remainingAtStart)
        case .recurring:
            var candidate = (remainingAtStart / 30).rounded(.down) * 30
            // Never fire on the very first tick: step inside the remaining window.
            if candidate >= remainingAtStart { candidate -= 30 }
            nextBeepAt = candidate
        }
    }

    /// Call once per countdown tick with the current time remaining.
    ///
    /// Returns `true` exactly once per boundary as `remaining` crosses it, and
    /// advances the schedule to the next boundary (recurring) or retires it
    /// (end-only). Returns `false` when no reminder is due.
    mutating func shouldBeep(remaining: TimeInterval) -> Bool {
        guard nextBeepAt > 0, remaining <= nextBeepAt else { return false }
        switch mode {
        case .recurring: nextBeepAt -= 30
        case .endOnly: nextBeepAt = 0
        }
        return true
    }
}
