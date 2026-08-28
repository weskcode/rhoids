import Testing
import Foundation
@testable import RHOIDS

// MARK: - Tags

extension Tag {
    @Tag static var appGroup: Self
    @Tag static var widgetContract: Self
}

// MARK: - Suite

/// Tests for SharedStateService - the App Group UserDefaults bridge that the
/// widget intent writes and the host app reads.
///
/// The most common reason the widget works on the simulator but not on a
/// physical device is that `UserDefaults(suiteName: "group.com.wesley.RHOIDS")`
/// returns **nil** on device when the App Group entitlement is missing from the
/// provisioning profile. Every write silently does nothing, so the app opens
/// but finds no timer state.
@MainActor
struct SharedStateServiceTests {
    // Each test struct instance gets a unique, isolated suite - no cross-test
    // pollution even when tests run in parallel.
    private let suiteName = "com.test.rhoids.sharedstate-\(UUID().uuidString)"

    private var service: SharedStateService {
        SharedStateService(suiteName: suiteName)
    }

    // MARK: - Round-trip

    @Test("setTimer and getTimerState preserve all fields")
    func writeAndReadRoundTrip() throws {
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let svc = service
        let endDate = Date().addingTimeInterval(180)

        svc.setTimer(endDate: endDate, presetName: "Recommended", duration: 180)
        let state = svc.getTimerState()

        #expect(state.isRunning == true, "isRunning must be true after setTimer")
        let readEnd = try #require(state.endDate, "endDate must survive round-trip")
        #expect(abs(readEnd.timeIntervalSince(endDate)) < 0.01)
        #expect(state.presetName == "Recommended")
        #expect(state.duration == 180)
    }

    @Test("A second setTimer fully overwrites the first with no residue")
    func overwriteReplacesAllFields() {
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let svc = service

        svc.setTimer(endDate: Date().addingTimeInterval(60), presetName: "Recommended", duration: 60)
        svc.setTimer(endDate: Date().addingTimeInterval(300), presetName: "Max", duration: 300)

        let state = svc.getTimerState()
        #expect(state.presetName == "Max", "second write should replace presetName")
        #expect(state.duration == 300, "second write should replace duration")
    }

    // MARK: - clearTimer

    @Test("clearTimer resets every key back to idle")
    func clearTimerResetsAllKeys() {
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let svc = service

        svc.setTimer(endDate: Date().addingTimeInterval(180), presetName: "Recommended", duration: 180)
        svc.clearTimer()
        let state = svc.getTimerState()

        #expect(state.isRunning == false)
        #expect(state.endDate == nil)
        #expect(state.presetName == nil)
        #expect(state.duration == 0)
    }

    @Test("Fresh suite returns all-nil idle state")
    func freshSuiteIsIdle() {
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let state = service.getTimerState()

        #expect(state.isRunning == false)
        #expect(state.endDate == nil)
        #expect(state.duration == 0)
    }

    // MARK: - Cross-instance (simulates cross-process read)

    /// The widget intent writes state in the extension process; the host app reads
    /// it in a different process via a second UserDefaults instance on the same suite.
    /// This test simulates that boundary.
    @Test("State written by one instance is immediately visible to a second instance",
          .tags(.widgetContract))
    func crossInstanceReadback() throws {
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let writer = service
        let endDate = Date().addingTimeInterval(240)

        writer.setTimer(endDate: endDate, presetName: "Max", duration: 300)

        // New instance, same suite - simulates the app process reading what the
        // widget extension process wrote.
        let reader = SharedStateService(suiteName: suiteName)
        let state = reader.getTimerState()

        #expect(state.isRunning == true)
        let readEnd = try #require(state.endDate)
        #expect(abs(readEnd.timeIntervalSince(endDate)) < 0.01)
        #expect(state.presetName == "Max")
    }

    // MARK: - App Group availability (device diagnostic)

    /// On a physical device where the App Group isn't in the provisioning profile,
    /// `UserDefaults(suiteName: "group.…")` returns **nil**. The service must
    /// handle that gracefully: no crash, and getTimerState returns all-nil idle.
    ///
    /// If the widget breaks only on device, this is the first thing to check.
    @Test("getTimerState is safe when the App Group suite is nil (device provisioning failure)",
          .tags(.appGroup))
    func safeWhenAppGroupSuiteIsNil() {
        // A group-prefixed name that cannot be provisioned → returns nil on device.
        let unavailableSuite = "group.com.never.provisioned.rhoids.\(UUID().uuidString)"
        let svc = SharedStateService(suiteName: unavailableSuite)
        let state = svc.getTimerState()

        #expect(state.isRunning == false, "must not crash and must report idle")
        #expect(state.endDate == nil)
        #expect(state.duration == 0)
    }

    /// This test **will fail on a physical device** where the App Group entitlement
    /// is absent from the provisioning profile. Run it when diagnosing device-only
    /// widget failures: a failure here means the App Group is the root cause.
    @Test("Production App Group suite is readable and writable on this device",
          .tags(.appGroup))
    func productionAppGroupIsAccessible() throws {
        let message: Comment = "App Group 'group.com.wesley.RHOIDS' is inaccessible. On device: verify App Groups capability is enabled and the provisioning profile includes it."
        let defaults = try #require(UserDefaults(suiteName: "group.com.wesley.RHOIDS"), message)

        let sentinel = "sentinel-\(UUID().uuidString)"
        defaults.set(sentinel, forKey: "__test_sentinel__")
        let readback = defaults.string(forKey: "__test_sentinel__")
        defaults.removeObject(forKey: "__test_sentinel__")

        #expect(readback == sentinel, "App Group defaults must support write-then-read")
    }

    // MARK: - nonisolated thread safety

    @Test("getTimerState (nonisolated) is callable from off-MainActor contexts",
          .tags(.widgetContract))
    func getTimerStateFromBackgroundIsolation() async throws {
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        let svc = service
        svc.setTimer(endDate: Date().addingTimeInterval(180), presetName: "Recommended", duration: 180)

        // TimerService is an actor - it calls getTimerState() without a MainActor hop.
        // Verify that holds here too.
        let state = await Task.detached {
            svc.getTimerState()
        }.value

        #expect(state.isRunning == true)
        #expect(state.presetName == "Recommended")
    }
}
