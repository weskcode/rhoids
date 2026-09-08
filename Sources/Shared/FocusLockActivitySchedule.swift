import DeviceActivity
import Foundation

/// Builds Device Activity schedules for RHOIDS timers and cooldowns that are
/// shorter than Apple's 15-minute minimum monitoring interval.
///
/// For any shorter activity, the monitored interval lasts 15 minutes and its
/// end-warning callback fires at the user's real deadline. The monitor handles
/// that warning as the effective end instead of waiting for the artificial
/// interval end.
enum FocusLockActivitySchedule {
    static let minimumMonitoringDuration: TimeInterval = 15 * 60

    struct Plan {
        let schedule: DeviceActivitySchedule
        let usesEndWarning: Bool
        let monitoringDuration: TimeInterval
        let endWarningOffset: TimeInterval?
    }

    static func make(
        startingAt start: Date,
        duration: TimeInterval,
        calendar: Calendar = .current
    ) -> Plan {
        let safeDuration = max(1, duration)
        let monitoringDuration = max(safeDuration, minimumMonitoringDuration)
        let monitoringEnd = start.addingTimeInterval(monitoringDuration)
        let usesEndWarning = safeDuration < minimumMonitoringDuration

        let warningInterval = Int(minimumMonitoringDuration - safeDuration)
        let warningTime: DateComponents? = usesEndWarning
            ? DateComponents(minute: warningInterval / 60, second: warningInterval % 60)
            : nil

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
                from: start
            ),
            intervalEnd: calendar.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
                from: monitoringEnd
            ),
            repeats: false,
            warningTime: warningTime
        )

        return Plan(
            schedule: schedule,
            usesEndWarning: usesEndWarning,
            monitoringDuration: monitoringDuration,
            endWarningOffset: usesEndWarning ? TimeInterval(warningInterval) : nil
        )
    }
}

/// Pure decision logic behind `FocusLockMonitor.extendCooldownIfNeeded(pastDeadline:)`: whether
/// a duplicate bathroom-session-end delivery should extend the stored cooldown deadline, no-op,
/// or (if restarting monitoring for the extended deadline fails) restore the original deadline
/// and re-arm a fallback schedule for whatever time is left on it.
///
/// Lives in `Sources/Shared` rather than on `FocusLockMonitor` itself because the Device
/// Activity monitor extension can't import the main app target (see the note at the top of
/// `FocusLockMonitor.swift`) - this file is the one already shared between that extension and
/// the app target, which also makes the decision unit-testable via `@testable import RHOIDS`
/// without touching real Screen Time APIs. Mirrors `ScreenTimeService.extendedDeadline`, the
/// same fix applied on the app-side equivalent of this callback.
enum FocusLockCooldownExtension {
    /// Whether extending the cooldown to a fresh `duration` from now would push the deadline
    /// later than `existingDeadline`. `nil` means no-op: a genuine duplicate delivery where the
    /// "new" deadline would land at or before the existing one, so the earlier cooldown should
    /// keep ticking down untouched rather than being silently shortened.
    static func extendedDeadline(pastDeadline existingDeadline: Date, duration: TimeInterval) -> Date? {
        let candidateDeadline = Date.now.addingTimeInterval(duration)
        return candidateDeadline > existingDeadline ? candidateDeadline : nil
    }

    /// What to restore when `extendedDeadline` found a later deadline but restarting Device
    /// Activity monitoring for it failed: the original deadline (so the shield's expiry still
    /// matches what monitoring will actually watch for), plus however much time is left on it
    /// to size a fallback schedule so something keeps watching the shield at all.
    static func fallbackAfterFailedExtension(
        pastDeadline existingDeadline: Date,
        now: Date = .now
    ) -> (deadline: Date, monitoringDuration: TimeInterval) {
        (existingDeadline, existingDeadline.timeIntervalSince(now))
    }
}
