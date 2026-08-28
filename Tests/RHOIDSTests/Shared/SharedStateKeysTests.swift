import Testing
import Foundation
@testable import RHOIDS

struct SharedStateKeysTests {
    @Test func `Suite name matches the App Group identifier`() {
        #expect(SharedStateKeys.suiteName == "group.com.wesley.RHOIDS",
                "Suite name must match the App Group in entitlements")
    }

    @Test func `All keys are unique`() {
        let keys = [
            SharedStateKeys.timerEndDate,
            SharedStateKeys.timerIsRunning,
            SharedStateKeys.timerPresetName,
            SharedStateKeys.timerDuration,
        ]
        #expect(Set(keys).count == keys.count, "All shared state keys must be unique")
    }

    @Test func `All keys are non-empty`() {
        #expect(SharedStateKeys.timerEndDate.isEmpty == false)
        #expect(SharedStateKeys.timerIsRunning.isEmpty == false)
        #expect(SharedStateKeys.timerPresetName.isEmpty == false)
        #expect(SharedStateKeys.timerDuration.isEmpty == false)
    }
}
