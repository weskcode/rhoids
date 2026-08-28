import Testing
import Foundation
@testable import RHOIDS

struct FocusLockModeTests {

    // MARK: - startReminder

    @Test func `phoneFree has a start reminder`() {
        let copy = FocusLockMode.phoneFree.startReminder
        #expect(copy != nil, "Phone-Free is the only path that needs a start-of-timer nudge")
        #expect(copy?.title == "PUT YOUR PHONE DOWN!")
        #expect(copy?.body.isEmpty == false)
    }

    @Test func `limitedScrolling has no start reminder`() {
        #expect(FocusLockMode.limitedScrolling.startReminder == nil,
                "Limited Scrolling expects the user to use their phone during the timer")
    }

    // MARK: - completionCopy

    @Test func `phoneFree completion copy does not claim apps are blocked`() {
        let copy = FocusLockMode.phoneFree.completionCopy(cooldownMinutes: 5)
        #expect(copy.title.localizedCaseInsensitiveContains("block") == false)
        #expect(copy.body.localizedCaseInsensitiveContains("block") == false)
    }

    @Test func `limitedScrolling completion copy is not the phone-down message`() {
        let copy = FocusLockMode.limitedScrolling.completionCopy(cooldownMinutes: 5)
        #expect(copy.title != "PUT YOUR PHONE DOWN!",
                "Limited Scrolling must never surface the Phone-Free primary message")
        #expect(copy.body.contains("PUT YOUR PHONE DOWN") == false)
    }

    @Test(arguments: [1, 5, 10, 15, 30])
    func `limitedScrolling completion copy reflects the configured cooldown minutes`(minutes: Int) {
        let copy = FocusLockMode.limitedScrolling.completionCopy(cooldownMinutes: minutes)
        #expect(copy.body.contains("\(minutes)"),
                "Body should mention the actual cooldown duration, not a hardcoded one")
    }

    @Test func `alarmKitTitle matches the completion copy title`() {
        for mode in FocusLockMode.allCases {
            #expect(mode.alarmKitTitle(cooldownMinutes: 5) == mode.completionCopy(cooldownMinutes: 5).title,
                    "The AlarmKit full-screen alert and the fallback notification must show the same title")
        }
    }

    // MARK: - effective(selected:blockingWillEngage:)

    @Test func `effective returns phoneFree regardless of blockingWillEngage`() {
        #expect(FocusLockMode.effective(selected: .phoneFree, blockingWillEngage: false) == .phoneFree)
        #expect(FocusLockMode.effective(selected: .phoneFree, blockingWillEngage: true) == .phoneFree)
    }

    @Test func `effective returns limitedScrolling when blocking will engage`() {
        #expect(FocusLockMode.effective(selected: .limitedScrolling, blockingWillEngage: true) == .limitedScrolling)
    }

    @Test func `effective returns nil when limitedScrolling was picked but blocking will not engage`() {
        #expect(FocusLockMode.effective(selected: .limitedScrolling, blockingWillEngage: false) == nil,
                "Must never claim apps are blocked (e.g. authorization denied, no apps picked) when they aren't")
    }
}
