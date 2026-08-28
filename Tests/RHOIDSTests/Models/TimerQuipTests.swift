import Testing
@testable import RHOIDS

extension TimerQuip: @retroactive CustomTestStringConvertible {
    public var testDescription: String { body }
}

struct TimerQuipTests {
    @Test func `Completion quips array is not empty`() {
        #expect(TimerQuip.completionQuips.isEmpty == false)
    }

    @Test func `Early stop quips array is not empty`() {
        #expect(TimerQuip.earlyStopQuips.isEmpty == false)
    }

    @Test("All completion quips are non-empty strings",
          arguments: TimerQuip.completionQuips)
    func allCompletionQuipsNonEmpty(quip: TimerQuip) {
        #expect(quip.body.isEmpty == false,
                "Quip body should not be empty")
    }

    @Test("All early stop quips are non-empty strings",
          arguments: TimerQuip.earlyStopQuips)
    func allEarlyStopQuipsNonEmpty(quip: TimerQuip) {
        #expect(quip.body.isEmpty == false,
                "Quip body should not be empty")
    }

    @Test func `Random completion returns a valid quip`() {
        let quip = TimerQuip.randomCompletion()
        #expect(TimerQuip.completionQuips.contains { $0.id == quip.id })
    }

    @Test func `Random early stop returns a valid quip`() {
        let quip = TimerQuip.randomEarlyStop()
        #expect(TimerQuip.earlyStopQuips.contains { $0.id == quip.id })
    }

    @Test func `Beep quips array is not empty`() {
        #expect(TimerQuip.beepQuips.isEmpty == false)
    }

    @Test func `Warning quips array is not empty`() {
        #expect(TimerQuip.warningQuips.isEmpty == false)
    }

    @Test("All beep quips are non-empty strings",
          arguments: TimerQuip.beepQuips)
    func allBeepQuipsNonEmpty(quip: TimerQuip) {
        #expect(quip.body.isEmpty == false,
                "Quip body should not be empty")
    }

    @Test("All warning quips are non-empty strings",
          arguments: TimerQuip.warningQuips)
    func allWarningQuipsNonEmpty(quip: TimerQuip) {
        #expect(quip.body.isEmpty == false,
                "Quip body should not be empty")
    }

    @Test func `Random beep returns a valid quip`() {
        let quip = TimerQuip.randomBeep()
        #expect(TimerQuip.beepQuips.contains { $0.id == quip.id })
    }

    @Test func `Random warning returns a valid quip`() {
        let quip = TimerQuip.randomWarning()
        #expect(TimerQuip.warningQuips.contains { $0.id == quip.id })
    }

    @Test func `Random completion produces variety`() {
        var seen = Set<String>()
        for _ in 0..<20 {
            seen.insert(TimerQuip.randomCompletion().body)
        }
        #expect(seen.count > 1)
    }

    @Test func `Random beep produces variety`() {
        var seen = Set<String>()
        for _ in 0..<20 {
            seen.insert(TimerQuip.randomBeep().body)
        }
        #expect(seen.count > 1)
    }

    @Test func `Random warning produces variety`() {
        var seen = Set<String>()
        for _ in 0..<20 {
            seen.insert(TimerQuip.randomWarning().body)
        }
        #expect(seen.count > 1)
    }

    @Test func `Beep quips contain anti-rush messaging`() {
        let allBodies = TimerQuip.beepQuips.map(\.body).joined(separator: " ")
        let antiRushTerms = ["push", "rush", "relax", "strain", "later", "patience"]
        let matchCount = antiRushTerms.filter { allBodies.localizedCaseInsensitiveContains($0) }.count
        #expect(matchCount >= 3,
                "Beep quips should contain anti-rush language (found \(matchCount) of \(antiRushTerms.count) terms)")
    }

    @Test func `Warning quips contain anti-rush messaging`() {
        let allBodies = TimerQuip.warningQuips.map(\.body).joined(separator: " ")
        let antiRushTerms = ["rush", "push", "strain", "relax", "later", "walk away"]
        let matchCount = antiRushTerms.filter { allBodies.localizedCaseInsensitiveContains($0) }.count
        #expect(matchCount >= 3,
                "Warning quips should contain anti-rush language (found \(matchCount) of \(antiRushTerms.count) terms)")
    }

    @Test func `Quip IDs are unique across all categories`() {
        let allQuips = TimerQuip.completionQuips + TimerQuip.earlyStopQuips
            + TimerQuip.beepQuips + TimerQuip.warningQuips
        let ids = Set(allQuips.map(\.id))
        #expect(ids.count == allQuips.count)
    }

    @Test func `Quip is sendable`() async {
        let quip = TimerQuip(body: "test")
        await Task.detached {
            #expect(quip.body == "test")
        }.value
    }
}
