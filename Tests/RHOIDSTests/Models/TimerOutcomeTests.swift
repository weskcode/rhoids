import Testing
@testable import RHOIDS

struct TimerOutcomeTests {
    private let completionQuip = TimerQuip(body: "Test completion")
    private let earlyStopQuip = TimerQuip(body: "Test early stop")

    @Test func `Completed outcome has correct title and icon`() {
        let outcome = TimerOutcome.completed(completionQuip)
        #expect(outcome.title == "TIME’S UP")
        #expect(outcome.iconSymbol == "checkmark.circle.fill")
        #expect(outcome.playsAlarm == true)
    }

    @Test func `Stopped early outcome has correct title and icon`() {
        let outcome = TimerOutcome.stoppedEarly(earlyStopQuip)
        #expect(outcome.title == "STOPPED EARLY")
        #expect(outcome.iconSymbol == "hand.thumbsup.fill")
        #expect(outcome.playsAlarm == false)
    }

    @Test func `Outcome wraps its quip`() {
        let completed = TimerOutcome.completed(completionQuip)
        #expect(completed.quip.body == "Test completion")

        let stopped = TimerOutcome.stoppedEarly(earlyStopQuip)
        #expect(stopped.quip.body == "Test early stop")
    }

    @Test func `Outcome IDs are unique across cases`() {
        let completed = TimerOutcome.completed(completionQuip)
        let stopped = TimerOutcome.stoppedEarly(earlyStopQuip)
        #expect(completed.id != stopped.id)
    }

    @Test func `Outcome IDs are unique within same case with different quips`() {
        let q1 = TimerQuip(body: "One")
        let q2 = TimerQuip(body: "Two")
        let o1 = TimerOutcome.completed(q1)
        let o2 = TimerOutcome.completed(q2)
        #expect(o1.id != o2.id)
    }

    @Test func `Outcome is sendable`() async {
        let outcome = TimerOutcome.completed(completionQuip)
        await Task.detached {
            #expect(outcome.title == "TIME’S UP")
        }.value
    }
}
