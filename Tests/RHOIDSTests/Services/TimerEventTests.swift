import Testing
import Foundation
@testable import RHOIDS

/// Tests for TimerEvent - the events that flow from TimerService to listeners.
struct TimerEventTests {
    @Test func `Started event carries all required fields`() {
        let endDate = Date().addingTimeInterval(180)
        let preset = PresetTimer.recommended
        let event = TimerEvent.started(endDate: endDate, preset: preset, duration: 180)

        if case .started(let date, let p, let d) = event {
            #expect(date == endDate)
            #expect(p == preset)
            #expect(d == 180)
        } else {
            Issue.record("Expected .started event")
        }
    }

    @Test func `Tick event carries remaining time`() {
        let event = TimerEvent.tick(remaining: 42.5)
        if case .tick(let remaining) = event {
            #expect(remaining == 42.5)
        } else {
            Issue.record("Expected .tick event")
        }
    }

    @Test func `Completed event carries preset and duration`() {
        let preset = PresetTimer.maxAllowed
        let event = TimerEvent.completed(preset: preset, duration: 300)
        if case .completed(let p, let d) = event {
            #expect(p == preset)
            #expect(d == 300)
        } else {
            Issue.record("Expected .completed event")
        }
    }

    @Test func `Completed event allows nil preset`() {
        let event = TimerEvent.completed(preset: nil, duration: 0)
        if case .completed(let p, _) = event {
            #expect(p == nil)
        } else {
            Issue.record("Expected .completed event")
        }
    }

    @Test func `Cancelled event has no associated data`() {
        let event = TimerEvent.cancelled
        if case .cancelled = event {
            // pass - correct case
        } else {
            Issue.record("Expected .cancelled event")
        }
    }

    @Test func `TimerEvent is Sendable`() async {
        let event = TimerEvent.started(
            endDate: Date().addingTimeInterval(60),
            preset: .recommended,
            duration: 60
        )
        await Task.detached {
            if case .started(_, let p, _) = event {
                #expect(p.name == "Recommended")
            }
        }.value
    }
}
