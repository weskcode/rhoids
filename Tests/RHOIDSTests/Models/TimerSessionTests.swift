import Testing
import Foundation
@testable import RHOIDS

struct TimerSessionTests {
    @Test func `Default initializer sets expected values`() {
        let session = TimerSession(plannedDuration: 180)
        #expect(session.plannedDuration == 180)
        #expect(session.wasInterrupted == false)
        #expect(session.endedAt == nil)
        #expect(session.presetName == nil)
    }

    @Test func `Full initializer preserves all fields`() {
        let start = Date()
        let end = start.addingTimeInterval(180)
        let id = UUID()

        let session = TimerSession(
            id: id,
            startedAt: start,
            plannedDuration: 180,
            endedAt: end,
            wasInterrupted: false,
            presetName: "Recommended"
        )

        #expect(session.id == id)
        #expect(session.startedAt == start)
        #expect(session.plannedDuration == 180)
        #expect(session.endedAt == end)
        #expect(session.wasInterrupted == false)
        #expect(session.presetName == "Recommended")
    }

    @Test func `actualDuration returns endedAt minus startedAt when endedAt is set`() {
        let start = Date()
        let end = start.addingTimeInterval(120)
        let session = TimerSession(startedAt: start, plannedDuration: 180, endedAt: end)
        #expect(abs(session.actualDuration - 120) < 0.01,
                "actualDuration should be 120s (ended early)")
    }

    @Test func `actualDuration falls back to plannedDuration when endedAt is nil`() {
        let session = TimerSession(plannedDuration: 300)
        #expect(session.actualDuration == 300,
                "Without endedAt, actualDuration should equal plannedDuration")
    }

    @Test func `Interrupted session records correctly`() {
        let session = TimerSession(
            plannedDuration: 180,
            endedAt: Date(),
            wasInterrupted: true,
            presetName: "Max"
        )
        #expect(session.wasInterrupted == true)
        #expect(session.presetName == "Max")
    }
}
