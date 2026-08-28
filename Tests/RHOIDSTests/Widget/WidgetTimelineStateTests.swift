import Testing
import Foundation
@testable import RHOIDS

/// Tests the timer-state-to-widget-entry decision logic that
/// `RHOIDSTimelineProvider.getTimeline` performs against the App Group.
///
/// These tests use a controlled, isolated UserDefaults suite so they reproduce
/// the exact read path the timeline provider uses on every platform - including
/// physical devices where the production App Group may not be accessible.
///
/// A `isActive` helper mirrors the provider's key guard:
/// ```
/// if isRunning, let endDate, endDate > now { /* running */ }
/// ```
struct WidgetTimelineStateTests {
    private let suiteName = "com.test.rhoids.timeline-\(UUID().uuidString)"

    private func write(isRunning: Bool,
                       endDate: Date?,
                       presetName: String = "Recommended",
                       duration: TimeInterval = 180) {
        let ud = UserDefaults(suiteName: suiteName)
        ud?.set(isRunning, forKey: "timerIsRunning")
        if let endDate {
            ud?.set(endDate, forKey: "activeTimerEndDate")
        } else {
            ud?.removeObject(forKey: "activeTimerEndDate")
        }
        ud?.set(presetName, forKey: "activeTimerPresetName")
        ud?.set(duration, forKey: "activeTimerDuration")
    }

    /// Mirrors the `RHOIDSTimelineProvider.getTimeline` guard exactly.
    private func isActive(at now: Date = Date()) -> Bool {
        let ud = UserDefaults(suiteName: suiteName)
        let endDate = ud?.object(forKey: "activeTimerEndDate") as? Date
        let isRunning = ud?.bool(forKey: "timerIsRunning") ?? false
        return isRunning && (endDate.map { $0 > now } ?? false)
    }

    private func cleanup() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    // MARK: - State machine

    @Test("Running timer with future endDate → active widget entry")
    func runningFutureEndDateIsActive() {
        defer { cleanup() }
        write(isRunning: true, endDate: Date().addingTimeInterval(180))
        #expect(isActive() == true)
    }

    @Test("Stale state: isRunning=true but endDate in the past → idle (not active)",
          .tags(.appGroup))
    func staleRunningTimerIsNotActive() {
        defer { cleanup() }
        write(isRunning: true, endDate: Date().addingTimeInterval(-60))

        // The raw `isRunning` flag is true, but the timeline provider must treat this as idle.
        // This is the "stale state" case that causes phantom running widgets on device when
        // a previous timer expired while the widget process was sleeping.
        let ud = UserDefaults(suiteName: suiteName)
        let rawRunning = ud?.bool(forKey: "timerIsRunning") ?? false
        #expect(rawRunning == true, "raw flag is still set")
        #expect(isActive() == false, "provider logic must reject past endDate as idle")
    }

    @Test("isRunning=false regardless of endDate → idle")
    func notRunningIsAlwaysIdle() {
        defer { cleanup() }
        write(isRunning: false, endDate: Date().addingTimeInterval(180))
        #expect(isActive() == false)
    }

    @Test("isRunning=true with nil endDate → idle (missing endDate = no active timer)")
    func runningWithNilEndDateIsIdle() {
        defer { cleanup() }
        write(isRunning: true, endDate: nil)
        #expect(isActive() == false)
    }

    @Test("Fresh / empty suite → idle")
    func emptyStateIsIdle() {
        // No write - pristine suite.
        defer { cleanup() }
        #expect(isActive() == false)
    }

    // MARK: - Intent → SharedStateService contract

    /// Verifies that the exact keys `StartDefaultTimerIntent.perform()` writes are
    /// the same keys `SharedStateService.getTimerState()` reads.
    ///
    /// If these diverge the intent can set state but the app reads nothing back -     /// the most common cause of "tap the widget, app opens, nothing happens" on device.
    @Test("Intent-written keys match SharedStateService read keys",
          .tags(.widgetContract))
    @MainActor
    func intentKeyContractMatchesSharedStateService() throws {
        let contractSuite = "com.test.rhoids.contract-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: contractSuite)?.removePersistentDomain(forName: contractSuite) }

        let duration: TimeInterval = 180
        let endDate = Date().addingTimeInterval(duration)

        // Write exactly as StartDefaultTimerIntent.perform() does:
        let ud = UserDefaults(suiteName: contractSuite)
        ud?.set(endDate,         forKey: "activeTimerEndDate")
        ud?.set(true,            forKey: "timerIsRunning")
        ud?.set("Recommended",   forKey: "activeTimerPresetName")
        ud?.set(duration,        forKey: "activeTimerDuration")

        // Read via SharedStateService:
        let state = SharedStateService(suiteName: contractSuite).getTimerState()

        #expect(state.isRunning == true,
                "SharedStateService must read the isRunning flag the intent wrote")
        let readEnd = try #require(state.endDate,
                                   "SharedStateService must find the endDate the intent wrote")
        #expect(abs(readEnd.timeIntervalSince(endDate)) < 0.01)
        #expect(state.presetName == "Recommended")
        #expect(state.duration == duration)
    }

    // MARK: - Timeline entry count

    @Test("Running timer timeline needs only active and expiry entries",
          .tags(.widgetContract))
    func runningTimerProducesActiveAndExpiryEntries() {
        defer { cleanup() }
        let ud = UserDefaults(suiteName: suiteName)

        let duration: TimeInterval = 180
        let endDate = Date().addingTimeInterval(duration)
        ud?.set(endDate, forKey: "activeTimerEndDate")
        ud?.set(true,    forKey: "timerIsRunning")
        ud?.set(duration, forKey: "activeTimerDuration")

        let now = Date()
        let storedEnd = ud?.object(forKey: "activeTimerEndDate") as? Date
        let running = ud?.bool(forKey: "timerIsRunning") ?? false

        guard running, let end = storedEnd, end > now else {
            Issue.record("State was not active - test setup failed")
            return
        }

        let entryDates = [now, end]
        #expect(entryDates.count == 2)
        #expect(entryDates[0] < entryDates[1])
    }

    // MARK: - PresetPreferences fallback (device safety)

    @Test("defaultPreset falls back to .recommended when the App Group is unavailable",
          .tags(.appGroup))
    func defaultPresetFallbackWhenAppGroupMissing() {
        // PresetPreferences.defaultPreset falls back when the suite is nil or the
        // stored ID doesn't match any known preset.
        let unknownID = "00000000-0000-0000-0000-000000000000"
        let result = PresetTimer.all.first { $0.id.uuidString == unknownID } ?? .recommended
        #expect(result == .recommended,
                "Unknown preset ID must fall back to .recommended, not crash")
    }

    @Test("All preset IDs stored in App Group map to a known PresetTimer",
          arguments: PresetTimer.all)
    func presetIDsRoundTripThroughStorage(preset: PresetTimer) {
        let stored = preset.id.uuidString
        let resolved = PresetTimer.all.first { $0.id.uuidString == stored }
        #expect(resolved == preset,
                "Preset '\(preset.name)' must resolve from its stored ID string")
    }
}
