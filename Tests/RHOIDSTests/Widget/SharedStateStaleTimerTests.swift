import Foundation
import Testing
@testable import RHOIDS

@MainActor
struct SharedStateStaleTimerTests {

    // MARK: - Stale timer detection

    @Test("getTimerState reports isRunning=true even when endDate is in the past")
    func staleTimerStillReportsRunning() throws {
        let suiteName = "com.test.rhoids.stale-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let svc = SharedStateService(suiteName: suiteName)
        let pastDate = Date().addingTimeInterval(-60)
        svc.setTimer(endDate: pastDate, presetName: "Recommended", duration: 180)

        let state = svc.getTimerState()
        #expect(state.isRunning == true,
                "SharedStateService stores the flag literally - it's the consumer's job to check endDate")
        let endDate = try #require(state.endDate)
        #expect(endDate < Date(),
                "endDate should be in the past, indicating a stale timer")
    }

    @Test("Consumer can detect stale timer by checking endDate against now")
    func consumerCanDetectStaleTimer() {
        let suiteName = "com.test.rhoids.stale-detect-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let svc = SharedStateService(suiteName: suiteName)
        let pastDate = Date().addingTimeInterval(-120)
        svc.setTimer(endDate: pastDate, presetName: "Max", duration: 300)

        let state = svc.getTimerState()
        let isActuallyRunning = state.isRunning && (state.endDate ?? .distantPast) > Date()

        #expect(isActuallyRunning == false,
                "A timer with a past endDate is effectively expired")
    }

    // MARK: - Partial state corruption scenarios

    @Test("getTimerState handles missing endDate with isRunning=true")
    func runningFlagWithoutEndDate() throws {
        let suiteName = "com.test.rhoids.partial-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(true, forKey: SharedStateKeys.timerIsRunning)
        // Deliberately not setting timerEndDate

        let svc = SharedStateService(suiteName: suiteName)
        let state = svc.getTimerState()

        #expect(state.isRunning == true)
        #expect(state.endDate == nil,
                "Missing endDate with isRunning=true is a corrupted state - should not crash")
    }

    @Test("getTimerState handles endDate present but isRunning=false")
    func endDateWithoutRunningFlag() throws {
        let suiteName = "com.test.rhoids.mismatch-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(Date().addingTimeInterval(120), forKey: SharedStateKeys.timerEndDate)
        defaults.set(false, forKey: SharedStateKeys.timerIsRunning)

        let svc = SharedStateService(suiteName: suiteName)
        let state = svc.getTimerState()

        #expect(state.isRunning == false,
                "isRunning=false should be respected even when endDate exists")
        #expect(state.endDate != nil,
                "endDate should still be readable")
    }

    // MARK: - clearTimer actually clears everything

    @Test("clearTimer removes all keys including duration and presetName")
    func clearTimerRemovesAllKeys() throws {
        let suiteName = "com.test.rhoids.clear-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let svc = SharedStateService(suiteName: suiteName)
        svc.setTimer(endDate: Date().addingTimeInterval(180), presetName: "Recommended", duration: 180)
        svc.clearTimer()

        let defaults = try #require(UserDefaults(suiteName: suiteName))
        #expect(defaults.object(forKey: SharedStateKeys.timerEndDate) == nil)
        #expect(defaults.bool(forKey: SharedStateKeys.timerIsRunning) == false)
        #expect(defaults.object(forKey: SharedStateKeys.timerPresetName) == nil)
        #expect(defaults.object(forKey: SharedStateKeys.timerDuration) == nil)
    }

    // MARK: - Rapid write/clear cycling

    @Test("Rapid set/clear/set/clear leaves clean state")
    func rapidSetClearCycling() {
        let suiteName = "com.test.rhoids.rapid-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let svc = SharedStateService(suiteName: suiteName)
        for i in 0..<10 {
            svc.setTimer(
                endDate: Date().addingTimeInterval(TimeInterval(i * 60)),
                presetName: "Preset-\(i)",
                duration: TimeInterval(i * 60)
            )
            svc.clearTimer()
        }

        let state = svc.getTimerState()
        #expect(state.isRunning == false)
        #expect(state.endDate == nil)
        #expect(state.presetName == nil)
        #expect(state.duration == 0)
    }

    // MARK: - Timer adoption guard (testing the pattern TimerService uses)

    @Test("adoptSharedStateIfNeeded pattern rejects expired timers")
    func adoptionPatternRejectsExpiredTimer() throws {
        let suiteName = "com.test.rhoids.adopt-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let svc = SharedStateService(suiteName: suiteName)
        let pastDate = Date().addingTimeInterval(-30)
        svc.setTimer(endDate: pastDate, presetName: "Recommended", duration: 180)

        let state = svc.getTimerState()
        let endDate = try #require(state.endDate)
        let shouldAdopt = state.isRunning
            && endDate > Date()

        #expect(shouldAdopt == false,
                "Expired shared timer should not be adopted")
    }

    @Test("adoptSharedStateIfNeeded pattern accepts valid future timer")
    func adoptionPatternAcceptsValidTimer() throws {
        let suiteName = "com.test.rhoids.adopt-valid-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

        let svc = SharedStateService(suiteName: suiteName)
        let futureDate = Date().addingTimeInterval(120)
        svc.setTimer(endDate: futureDate, presetName: "Recommended", duration: 180)

        let state = svc.getTimerState()
        let endDate = try #require(state.endDate)
        let shouldAdopt = state.isRunning
            && endDate > Date()

        #expect(shouldAdopt == true)
    }
}
