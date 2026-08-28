import AlarmKit
import Foundation
import SwiftUI
import os.log

/// Empty metadata marker required by `AlarmAttributes`. Reserved for
/// future extension (e.g., storing the originating preset ID).

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "AlarmKit")

struct RHOIDSAlarmMetadata: AlarmMetadata {}

/// Wraps Apple's iOS 26 AlarmKit so the timer's end fires a system-level
/// full-screen alarm - playing through Silent mode and Focus, taking over
/// the screen regardless of which app the user is in.
///
/// Persists the active alarm's UUID into the App Group so either the main
/// app or the widget extension can cancel an alarm the other one scheduled.
actor AlarmKitService {
    static let activeIDKey = "activeAlarmKitID"
    static let suiteName = SharedStateKeys.suiteName

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.suiteName)
    }

    /// Whether AlarmKit is available in the current environment.
    /// AlarmKit relies on system daemons that don't run on the Simulator,
    /// so we skip all AlarmKit calls there to avoid hangs.
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// Synchronous current-state check - no prompt.
    var isAuthorized: Bool {
        guard !isSimulator else { return false }
        return AlarmManager.shared.authorizationState == .authorized
    }

    /// Prompts the user the first time it's called. Subsequent calls return
    /// the cached state. Returns `true` if scheduling is permitted.
    func requestAuthorization() async -> Bool {
        guard !isSimulator else {
            log.debug("requestAuthorization skipped - simulator")
            return false
        }
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .notDetermined:
            do {
                let state = try await manager.requestAuthorization()
                let granted = state == .authorized
                log.debug("requestAuthorization - granted=\(granted)")
                return granted
            } catch {
                log.debug("requestAuthorization error: \(error)")
                return false
            }
        case .authorized:
            return true
        case .denied:
            log.debug("authorization denied")
            return false
        @unknown default:
            return false
        }
    }

    /// Schedules a system alarm that fires after `duration` seconds. Returns
    /// the alarm's UUID on success, or `nil` if not authorized or scheduling
    /// failed. Stores the ID in the App Group so `cancelActive()` can find it
    /// from either process.
    @discardableResult
    func scheduleTimer(
        duration: TimeInterval,
        presetName: String,
        messagingMode: FocusLockMode? = nil,
        cooldownMinutes: Int = 5
    ) async -> UUID? {
        guard !isSimulator else {
            log.debug("scheduleTimer skipped - simulator")
            return nil
        }
        guard isAuthorized else {
            log.debug("scheduleTimer skipped - not authorized")
            return nil
        }

        await cancelActive()

        let title = messagingMode?.alarmKitTitle(cooldownMinutes: cooldownMinutes) ?? "Time's up, RHOIDS!"

        // iOS 26.0 requires an explicit stopButton; 26.1+ provides system UI automatically.
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title))
        } else {
            let stopButton = AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.fill"
            )
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title), stopButton: stopButton)
        }
        let attributes = AlarmAttributes<RHOIDSAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .brand
        )

        let id = UUID()
        do {
            log.debug("scheduling alarm - id=\(id), duration=\(duration)s, preset=\(presetName)")
            _ = try await AlarmManager.shared.schedule(
                id: id,
                configuration: .timer(
                    duration: duration,
                    attributes: attributes
                )
            )
            sharedDefaults?.set(id.uuidString, forKey: Self.activeIDKey)
            log.debug("scheduled alarm - id=\(id), duration=\(duration)s, preset=\(presetName)")
            return id
        } catch {
            log.error("schedule failed: \(error)")
            return nil
        }
    }

    /// Emits an alarm's UUID once it has *alerted* (fired) and then been
    /// removed - e.g. the user tapped Stop in the Dynamic Island, or the
    /// alarm finished on its own. This is the only signal the app gets when
    /// a system alarm is dismissed from outside the app, so it's what lets
    /// us tear down the parallel Live Activity / audio / notifications that
    /// were never given a chance to clean up (the app may have been
    /// suspended the entire time the timer ran).
    ///
    /// No-ops on the Simulator, where AlarmKit's daemons don't run.
    nonisolated func stoppedAlarms() -> AsyncStream<UUID> {
        AsyncStream { continuation in
            #if targetEnvironment(simulator)
            continuation.finish()
            #else
            let task = Task {
                var alerted = Set<UUID>()
                for await alarms in AlarmManager.shared.alarmUpdates {
                    let present = Set(alarms.map(\.id))
                    for alarm in alarms where alarm.state == .alerting {
                        alerted.insert(alarm.id)
                    }
                    // An alarm that started alerting and is now gone was
                    // stopped/dismissed by the user (or finished).
                    for stopped in alerted.subtracting(present) {
                        alerted.remove(stopped)
                        continuation.yield(stopped)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
            #endif
        }
    }

    /// Cancels the currently-tracked alarm if any. Safe to call when nothing
    /// is scheduled.
    func cancelActive() async {
        guard !isSimulator else { return }
        guard let idString = sharedDefaults?.string(forKey: Self.activeIDKey),
              let id = UUID(uuidString: idString) else { return }
        do {
            try AlarmManager.shared.cancel(id: id)
            log.debug("cancelled alarm - id=\(id)")
        } catch {
            log.error("cancel failed (likely already fired/dismissed): \(error)")
        }
        sharedDefaults?.removeObject(forKey: Self.activeIDKey)
    }
}
