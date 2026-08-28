import Foundation
import Testing
import UserNotifications
@testable import RHOIDS

/// A `NotificationSchedulingCenter` fake whose `add(_:)` sleeps before
/// recording the request - simulating the real latency of a
/// `UNUserNotificationCenter.add(_:)` XPC round-trip. This reproduces the
/// exact race the audit found: `NotificationService.schedule()` can still be
/// mid-flight inside `add()` when a concurrent `cancelAll()` runs, so a
/// naive "cancel now" would find nothing to remove and the request would
/// land moments later, un-cancellable.
actor DelayedNotificationSchedulingCenter: NotificationSchedulingCenter {
    private var requests: [String: UNNotificationRequest] = [:]
    private let addDelaySeconds: TimeInterval

    init(addDelay: TimeInterval = 0.2) {
        self.addDelaySeconds = addDelay
    }

    func add(_ request: UNNotificationRequest) async throws {
        // Deliberately NOT `Task.sleep` - that throws `CancellationError` the
        // instant the calling Swift Task is cancelled, which would make this
        // fake abort early and under-simulate the real bug. A real
        // `UNUserNotificationCenter.add(_:)` XPC call has already been
        // dispatched to a system daemon and completes on its own schedule
        // regardless of Swift-level task cancellation, so this delay must be
        // immune to it too - via a plain `DispatchQueue.asyncAfter` continuation.
        let delay = addDelaySeconds
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                continuation.resume()
            }
        }
        requests[request.identifier] = request
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        for identifier in identifiers {
            requests[identifier] = nil
        }
    }

    func pendingNotificationRequests() -> [UNNotificationRequest] {
        Array(requests.values)
    }
}

// Serialized: these assertions depend on tight, real wall-clock timing
// margins (a fixed artificial delay racing against explicit sleeps), so
// running them concurrently with each other risks scheduler contention
// producing spurious failures unrelated to the code under test.
// Time-limited: a regression here would hang on the `stop()` await instead
// of failing fast.
@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct TimerServiceSchedulingRaceTests {

    /// Notifications-only preferences: `notificationsEnabled` drives
    /// `timerAlertsEnabled`, which is what makes `prepareRemainingTimerSideEffects`
    /// call `notificationService.schedule(...)`. Warnings/haptics are off so
    /// the test only exercises the completion-notification scheduling path.
    private func notificationOnlyPrefs() -> TimerService.TimerPreferences {
        TimerService.TimerPreferences(
            notificationsEnabled: true,
            warningEnabled: false,
            warningMode: .endOnly,
            hapticsEnabled: false,
            alarmSound: .systemDefault,
            warningSound: .systemDefault
        )
    }

    private func makeService(center: DelayedNotificationSchedulingCenter) -> TimerService {
        TimerService(
            notificationService: NotificationService(center: center),
            liveActivityService: LiveActivityService(),
            sharedStateService: SharedStateService(suiteName: "com.test.rhoids.sched-race-\(UUID().uuidString)"),
            alarmPlayer: AlarmPlayer(),
            // AlarmKitService always resolves `scheduleTimer` to `nil` in the
            // Simulator/test host (`#if targetEnvironment(simulator)` guards
            // every AlarmKit call), so this test cannot exercise the AlarmKit
            // half of the race - that half can only be verified on a
            // physical device (see manual test plan). It's exercised here
            // purely as the real collaborator `prepareRemainingTimerSideEffects`
            // calls before scheduling notifications.
            alarmKitService: AlarmKitService(),
            screenTimeSessionScheduling: NoOpScreenTimeSessionScheduling(),
            sideEffectsEnabled: true // must be true - this is the path `sideEffectsEnabled: false` tests skip entirely
        )
    }

    private func waitForCompletion(
        from stream: AsyncStream<TimerEvent>,
        timeout: Duration = .seconds(5)
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                while let event = await iterator.next() {
                    if case .completed = event {
                        return true
                    }
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }

            let completed = await group.next() ?? false
            group.cancelAll()
            return completed
        }
    }

    @Test("Cancelling mid-schedule leaves no pending notification once stop() returns")
    func cancelDuringInFlightScheduleLeavesNoPendingRequest() async throws {
        let center = DelayedNotificationSchedulingCenter(addDelay: 0.2)
        let service = makeService(center: center)

        await service.start(duration: 120, preset: .recommended, preferences: notificationOnlyPrefs())

        // Stop almost immediately - well before the delayed `add()` call
        // (started inside the fire-and-forget-turned-tracked side-effects
        // task) has resolved. Pre-fix, `stop()` would call `cancelAll()`
        // immediately here, missing the request entirely.
        try? await Task.sleep(for: .milliseconds(20))
        await service.stop()

        // By the time `stop()` returns, it must have awaited the in-flight
        // scheduling task to completion and *then* cancelled - so no
        // trailing sleep should be needed for the assertion to hold. We add
        // a small margin only to guard against scheduler jitter, not because
        // the fix depends on it.
        try? await Task.sleep(for: .milliseconds(100))

        let pending = await center.pendingNotificationRequests()
        #expect(pending.isEmpty,
                "No notification should remain pending after cancelling mid-schedule; found: \(pending.map(\.identifier))")
    }

    @Test("Cancelling mid-schedule during an adopted timer leaves no pending notification")
    func cancelDuringInFlightAdoptedScheduleLeavesNoPendingRequest() async throws {
        let center = DelayedNotificationSchedulingCenter(addDelay: 0.2)
        let service = makeService(center: center)

        let endDate = Date().addingTimeInterval(120)
        await service.adopt(endDate: endDate, preset: .recommended, duration: 120)

        try? await Task.sleep(for: .milliseconds(20))
        await service.stop()

        try? await Task.sleep(for: .milliseconds(100))

        let pending = await center.pendingNotificationRequests()
        #expect(pending.isEmpty,
                "No notification should remain pending after cancelling an adopted timer mid-schedule; found: \(pending.map(\.identifier))")
    }

    @Test("Natural completion during an in-flight schedule leaves no pending notification")
    func naturalCompletionDuringInFlightScheduleLeavesNoPendingRequest() async throws {
        let center = DelayedNotificationSchedulingCenter(addDelay: 2.5)
        let service = makeService(center: center)
        let events = await service.eventStream()

        await service.start(duration: 1.2, preset: .recommended, preferences: notificationOnlyPrefs())

        let completed = await waitForCompletion(from: events, timeout: .seconds(10))
        #expect(completed, "The short timer should naturally complete during the delayed notification add")

        // If completion cleanup does not await the in-flight scheduling task,
        // the delayed request lands after `notificationService.cancelAll()`
        // and remains pending here.
        try? await Task.sleep(for: .milliseconds(100))
        let pending = await center.pendingNotificationRequests()
        #expect(pending.isEmpty,
                "No notification should remain pending after natural completion races an in-flight schedule; found: \(pending.map(\.identifier))")
    }

    @Test("Rapid start-stop-start does not leave the first start's schedule pending")
    func rapidRestartDuringInFlightScheduleLeavesOnlyLatestPending() async throws {
        let center = DelayedNotificationSchedulingCenter(addDelay: 0.2)
        let service = makeService(center: center)

        await service.start(duration: 120, preset: .recommended, preferences: notificationOnlyPrefs())
        try? await Task.sleep(for: .milliseconds(20))
        // Second start before the first's `add()` has resolved - `start()`
        // now cancels-and-awaits the prior side-effects task before this
        // new one begins, so the two schedule calls can't interleave.
        await service.start(duration: 60, preset: .maxAllowed, preferences: notificationOnlyPrefs())

        try? await Task.sleep(for: .milliseconds(400))

        let pending = await center.pendingNotificationRequests()
        let completions = pending.filter { $0.identifier == "rhoids.timer.complete" }
        #expect(completions.count == 1, "Exactly one completion notification should be pending, not stacked duplicates")
        #expect(completions.first?.content.subtitle == "Max", "The pending completion should belong to the second (latest) timer")

        await service.stop()
    }

    // MARK: - rescheduleForFocusLockChange()

    @Test("rescheduleForFocusLockChange is a no-op when nothing is running")
    func rescheduleNoOpWhenIdle() async {
        let center = DelayedNotificationSchedulingCenter(addDelay: 0.05)
        let service = makeService(center: center)

        await service.rescheduleForFocusLockChange()

        let pending = await center.pendingNotificationRequests()
        #expect(pending.isEmpty, "Nothing should be scheduled when no timer is running")
    }

    @Test("Rescheduling replaces, not duplicates, the completion notification")
    func rescheduleReplacesCompletionWithoutDuplicating() async throws {
        let center = DelayedNotificationSchedulingCenter(addDelay: 0.2)
        let service = makeService(center: center)

        await service.start(duration: 120, preset: .recommended, preferences: notificationOnlyPrefs())
        // rescheduleForFocusLockChange() internally awaits start()'s in-flight
        // scheduling before spawning its own, so no manual wait is needed here.
        await service.rescheduleForFocusLockChange()
        // ...but its *own* spawned scheduling task still needs time to land.
        try? await Task.sleep(for: .milliseconds(400))

        let pending = await center.pendingNotificationRequests()
        let completions = pending.filter { $0.identifier == "rhoids.timer.complete" }
        #expect(completions.count == 1,
                "Reschedule must replace the completion notification, not stack a second one")

        await service.stop()
    }

    @Test("Cancelling during an in-flight reschedule leaves no pending notification once stop() returns")
    func cancelDuringInFlightRescheduleLeavesNoPendingRequest() async throws {
        let center = DelayedNotificationSchedulingCenter(addDelay: 0.2)
        let service = makeService(center: center)

        await service.start(duration: 120, preset: .recommended, preferences: notificationOnlyPrefs())
        await service.rescheduleForFocusLockChange()

        // Stop almost immediately - well before the delayed `add()` call
        // inside the reschedule's own `notificationService.schedule()` has
        // resolved.
        try? await Task.sleep(for: .milliseconds(20))
        await service.stop()

        try? await Task.sleep(for: .milliseconds(100))

        let pending = await center.pendingNotificationRequests()
        #expect(pending.isEmpty,
                "No notification should remain pending after cancelling mid-reschedule; found: \(pending.map(\.identifier))")
    }
}
