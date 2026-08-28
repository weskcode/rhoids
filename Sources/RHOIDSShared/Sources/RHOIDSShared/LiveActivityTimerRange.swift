import Foundation

/// Computes the guaranteed-valid date ranges a Live Activity needs to drive
/// its countdown text (`Text(timerInterval:)`) and progress bar
/// (`ProgressView(timerInterval:)`).
///
/// ## Why this exists
/// `Text(timerInterval:)` and `ProgressView(timerInterval:)` take a
/// `ClosedRange<Date>`. If that range is ever inverted (`lowerBound >
/// upperBound`) - which happens the instant a timer's `endDate` slips into the
/// past relative to "now" - constructing the range traps at runtime. Inside a
/// widget extension that trap blanks the *entire* snapshot: the Lock Screen
/// banner and every Dynamic Island region (compact, expanded, minimal) render
/// black because all regions are pre-rendered together.
///
/// This type clamps the inputs so both ranges are always valid:
/// - `end` is pushed to at least `now + minimumLead`, so it is strictly after
///   `now`.
/// - `start` is clamped to at most `now`, so the progress range is never empty.
///
/// Both the Lock Screen view and the Dynamic Island use this single source of
/// truth, so the snapshot-safety guarantee can be unit-tested once instead of
/// being re-derived (and re-broken) in each view.
public struct LiveActivityTimerRange: Equatable, Sendable {
    /// Reference instant the ranges were computed against (usually "now").
    public let reference: Date

    /// Clamped start of the timer - always `<= reference`.
    public let start: Date

    /// Clamped end of the timer - always `> reference`.
    public let end: Date

    /// Builds clamped ranges from a Live Activity's raw state.
    ///
    /// - Parameters:
    ///   - endDate: The timer's intended end (`ContentState.endDate`). May be
    ///     in the past if the timer expired while the widget was asleep.
    ///   - plannedDuration: The preset's total duration
    ///     (`Attributes.plannedDuration`). Non-positive values are treated as
    ///     `minimumLead`.
    ///   - now: The reference instant. Injected for testing; defaults to `.now`.
    ///   - minimumLead: The smallest gap to force between `now` and `end`.
    ///     Defaults to 1 second.
    public init(
        endDate: Date,
        plannedDuration: TimeInterval,
        now: Date = .now,
        minimumLead: TimeInterval = 1
    ) {
        let lead = max(minimumLead, 0.001)
        let safeEnd = max(endDate, now.addingTimeInterval(lead))
        let safeDuration = max(plannedDuration, lead)
        let safeStart = min(safeEnd.addingTimeInterval(-safeDuration), now)

        self.reference = now
        self.start = safeStart
        self.end = safeEnd
    }

    /// Range for the countdown label: `reference ... end`.
    /// Always valid because `end > reference`.
    public var remaining: ClosedRange<Date> {
        reference...end
    }

    /// Range for the progress bar: `start ... end`.
    /// Always valid because `start <= reference < end`.
    public var progress: ClosedRange<Date> {
        start...end
    }

    /// Snapshot progress from `start` to `end`, clamped to `0...1`.
    ///
    /// This is useful in very small widget surfaces where a static progress
    /// value is safer than a timer-driven `ProgressView(timerInterval:)`.
    public var fractionComplete: Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }

        let elapsed = reference.timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }

    /// Snapshot of the amount of the timer still remaining, clamped to `0...1`.
    public var fractionRemaining: Double {
        1 - fractionComplete
    }
}
