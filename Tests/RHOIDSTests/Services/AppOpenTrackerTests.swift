import Testing
import Foundation
@testable import RHOIDS

/// Each test builds the tracker over a fresh, per-test `UserDefaults`
/// suite, so the persisted open count never leaks between tests.
@MainActor
struct AppOpenTrackerTests {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "com.test.rhoids.appopen-\(UUID().uuidString)")!
    }

    @Test func `Open count key is stable`() {
        #expect(AppOpenTracker.openCountKey == "appOpenCount.v1",
                "Changing this key would reset all users' open counts")
    }

    @Test func `Fresh tracker starts at zero`() {
        let sut = AppOpenTracker(defaults: freshDefaults())
        #expect(sut.openCount == 0)
    }

    @Test func `First registration counts an open`() {
        let sut = AppOpenTracker(defaults: freshDefaults())
        #expect(sut.registerOpenIfNeeded() == 1)
        #expect(sut.openCount == 1)
    }

    @Test func `Repeated activations in one foreground session count once`() {
        let sut = AppOpenTracker(defaults: freshDefaults())
        sut.registerOpenIfNeeded()
        sut.registerOpenIfNeeded()
        sut.registerOpenIfNeeded()
        #expect(sut.openCount == 1,
                "Only the first .active transition per foreground session should count")
    }

    @Test func `Backgrounding re-arms the counter`() {
        let sut = AppOpenTracker(defaults: freshDefaults())
        sut.registerOpenIfNeeded()
        sut.sceneDidEnterBackground()
        sut.registerOpenIfNeeded()
        #expect(sut.openCount == 2,
                "Returning from the background is a new app open")
    }

    @Test func `Open count persists across relaunches`() {
        let defaults = freshDefaults()

        let launch1 = AppOpenTracker(defaults: defaults)
        launch1.registerOpenIfNeeded()
        launch1.sceneDidEnterBackground()
        launch1.registerOpenIfNeeded()

        let launch2 = AppOpenTracker(defaults: defaults)
        #expect(launch2.openCount == 2, "Count should hydrate from persisted state")
        #expect(launch2.registerOpenIfNeeded() == 3,
                "A cold launch counts as a new open")
    }
}
