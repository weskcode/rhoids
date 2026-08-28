import Testing
import Foundation
@testable import RHOIDS

extension Tag {
    @Tag static var liveActivity: Self
}

/// Tests the range-clamping logic that keeps a Live Activity's countdown text
/// and progress bar from forming an inverted `ClosedRange<Date>`. An inverted
/// range traps at runtime and blanks the entire widget snapshot (Lock Screen
/// banner + every Dynamic Island region), so these invariants are the
/// difference between a working and a black Live Activity on device.
@Suite(.tags(.liveActivity))
struct LiveActivityTimerRangeTests {

    // A fixed reference instant so tests are deterministic and order-independent.
    private let now = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Core invariant: ranges are ALWAYS valid

    @Test("Remaining range is never inverted",
          arguments: [-3600.0, -60, -1, -0.1, 0, 0.1, 1, 60, 180, 3600])
    func remainingRangeIsValid(endOffset: TimeInterval) {
        let range = LiveActivityTimerRange(
            endDate: now.addingTimeInterval(endOffset),
            plannedDuration: 180,
            now: now
        )
        #expect(range.remaining.lowerBound <= range.remaining.upperBound,
                "An inverted remaining range traps and blanks the widget")
    }

    @Test("Progress range is never inverted",
          arguments: [-3600.0, -60, -1, -0.1, 0, 0.1, 1, 60, 180, 3600])
    func progressRangeIsValid(endOffset: TimeInterval) {
        let range = LiveActivityTimerRange(
            endDate: now.addingTimeInterval(endOffset),
            plannedDuration: 180,
            now: now
        )
        #expect(range.progress.lowerBound <= range.progress.upperBound,
                "An inverted progress range traps and blanks the widget")
    }

    @Test("Ranges stay valid across the full duration × offset matrix",
          arguments: [-600.0, -1, 0, 1, 600], [-100.0, -1, 0, 1, 60, 600])
    func rangesValidForAllCombinations(endOffset: TimeInterval, duration: TimeInterval) {
        let range = LiveActivityTimerRange(
            endDate: now.addingTimeInterval(endOffset),
            plannedDuration: duration,
            now: now
        )
        #expect(range.remaining.lowerBound <= range.remaining.upperBound)
        #expect(range.progress.lowerBound <= range.progress.upperBound)
    }

    // MARK: - Boundary guarantees

    @Test("End is always strictly after the reference instant")
    func endIsAfterReference() {
        // Even with an endDate far in the past, end is pushed forward.
        let range = LiveActivityTimerRange(
            endDate: now.addingTimeInterval(-10_000),
            plannedDuration: 180,
            now: now
        )
        #expect(range.end > range.reference,
                "Countdown range reference...end must be non-empty")
    }

    @Test("Start is always at or before the reference instant")
    func startIsAtOrBeforeReference() {
        // A future endDate with a tiny duration would put the naive start in the
        // future; it must be clamped back to `now`.
        let range = LiveActivityTimerRange(
            endDate: now.addingTimeInterval(3600),
            plannedDuration: 1,
            now: now
        )
        #expect(range.start <= range.reference,
                "Progress range start must not sit in the future")
    }

    // MARK: - Happy path preserves real values

    @Test("Running timer keeps its real end date")
    func runningTimerKeepsRealEnd() {
        let realEnd = now.addingTimeInterval(180)
        let range = LiveActivityTimerRange(endDate: realEnd, plannedDuration: 180, now: now)
        #expect(range.end == realEnd, "A future end date must be used verbatim")
    }

    @Test("Running timer derives start from duration")
    func runningTimerDerivesStart() {
        let realEnd = now.addingTimeInterval(180)
        let range = LiveActivityTimerRange(endDate: realEnd, plannedDuration: 180, now: now)
        // start = min(end - duration, now) = min(now, now) = now
        #expect(range.start == now)
    }

    @Test("Mid-run timer exposes the true elapsed window")
    func midRunElapsedWindow() {
        // 60s of a 180s timer already elapsed → 120s remain.
        let realEnd = now.addingTimeInterval(120)
        let range = LiveActivityTimerRange(endDate: realEnd, plannedDuration: 180, now: now)
        // start = min(end - 180, now) = min(now - 60, now) = now - 60
        #expect(range.start == now.addingTimeInterval(-60))
        #expect(range.end == realEnd)
    }

    // MARK: - Degenerate duration handling

    @Test("Zero duration does not collapse the progress range")
    func zeroDurationIsHandled() {
        let range = LiveActivityTimerRange(
            endDate: now.addingTimeInterval(60),
            plannedDuration: 0,
            now: now
        )
        #expect(range.progress.lowerBound < range.progress.upperBound,
                "Zero duration must still yield a non-empty progress range")
    }

    @Test("Negative duration does not invert the progress range")
    func negativeDurationIsHandled() {
        let range = LiveActivityTimerRange(
            endDate: now.addingTimeInterval(60),
            plannedDuration: -500,
            now: now
        )
        #expect(range.progress.lowerBound <= range.progress.upperBound)
        #expect(range.start <= range.reference)
    }

    @Test("Fraction complete is clamped to 0...1",
          arguments: [-600.0, -1, 0, 1, 60, 600])
    func fractionCompleteIsClamped(endOffset: TimeInterval) {
        let range = LiveActivityTimerRange(
            endDate: now.addingTimeInterval(endOffset),
            plannedDuration: 180,
            now: now
        )

        #expect(range.fractionComplete >= 0)
        #expect(range.fractionComplete <= 1)
    }

    @Test("Mid-run fraction reflects elapsed progress")
    func midRunFractionComplete() {
        // 60s elapsed of a 180s timer.
        let realEnd = now.addingTimeInterval(120)
        let range = LiveActivityTimerRange(endDate: realEnd, plannedDuration: 180, now: now)

        #expect(abs(range.fractionComplete - (1.0 / 3.0)) < 0.0001)
    }

    @Test("Remaining fraction starts full and drains toward zero",
          arguments: [0.0, 60, 120, 179])
    func remainingFractionDrains(elapsed: TimeInterval) {
        let duration: TimeInterval = 180
        let endDate = now.addingTimeInterval(duration - elapsed)
        let range = LiveActivityTimerRange(
            endDate: endDate,
            plannedDuration: duration,
            now: now
        )

        let expected = (duration - elapsed) / duration
        #expect(abs(range.fractionRemaining - expected) < 0.0001)
    }

    // MARK: - minimumLead

    @Test("Custom minimum lead is honored for an expired timer")
    func customMinimumLead() {
        let range = LiveActivityTimerRange(
            endDate: now.addingTimeInterval(-100),
            plannedDuration: 180,
            now: now,
            minimumLead: 5
        )
        #expect(range.end == now.addingTimeInterval(5),
                "Expired timer should clamp end to now + minimumLead")
    }

    // MARK: - Value semantics

    @Test("Equatable: same inputs produce equal ranges")
    func equatableForSameInputs() {
        let a = LiveActivityTimerRange(endDate: now.addingTimeInterval(90), plannedDuration: 180, now: now)
        let b = LiveActivityTimerRange(endDate: now.addingTimeInterval(90), plannedDuration: 180, now: now)
        #expect(a == b)
    }
}
