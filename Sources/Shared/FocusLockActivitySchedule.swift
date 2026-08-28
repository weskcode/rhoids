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
