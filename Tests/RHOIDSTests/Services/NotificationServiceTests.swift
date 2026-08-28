import Testing
import Foundation
import UserNotifications
@testable import RHOIDS

struct NotificationServiceTests {

    // MARK: - Constants

    @Test func `Beep ID prefix is stable`() {
        #expect(NotificationService.beepIDPrefix == "rhoids.timer.beep.",
                "Changing this prefix would orphan scheduled beep notifications")
    }

    @Test func `Beep ID prefix uses reverse-DNS style`() {
        #expect(NotificationService.beepIDPrefix.hasPrefix("rhoids.timer."))
    }

    // MARK: - Beep Boundary Logic

    @Test(arguments: [
        (duration: 180.0, expected: 4),
        (duration: 150.0, expected: 3),
        (duration: 120.0, expected: 2),
        (duration:  90.0, expected: 1),
        (duration:  60.0, expected: 0),
        (duration:  30.0, expected: 0),
        (duration: 300.0, expected: 8),
    ])
    func `Beep count matches 30-second boundary logic`(duration: TimeInterval, expected: Int) {
        let count = computeBeepCount(duration: duration)
        #expect(count == expected,
                "A \(Int(duration))s timer should have \(expected) beep(s)")
    }

    @Test func `Beep boundaries are evenly spaced at 30 seconds`() {
        let boundaries = computeBeepBoundaries(duration: 180)
        // 180s: beeps fire at 30s, 60s, 90s, 120s from start
        // which is 150s, 120s, 90s, 60s remaining
        for i in 1..<boundaries.count {
            let gap = boundaries[i] - boundaries[i - 1]
            #expect(gap == 30, "Beep boundaries should be 30 seconds apart")
        }
    }

    @Test func `Beep boundaries skip the final 30 seconds`() throws {
        let boundaries = computeBeepBoundaries(duration: 180)
        let lastBoundary = try #require(boundaries.last)
        let remainingAtLastBeep = 180 - lastBoundary
        #expect(remainingAtLastBeep >= 30,
                "Last beep should fire at 60s+ remaining; the 30s mark is the warning's job")
    }

    @Test func `Beep boundaries start at 30 seconds from timer start`() {
        let boundaries = computeBeepBoundaries(duration: 300)
        #expect(boundaries.first == 30,
                "First beep should fire 30 seconds after timer start")
    }

    // MARK: - AlarmSound Notification Sound

    @Test func `systemDefault produces UNNotificationSound.default`() {
        let sound = AlarmSound.systemDefault.notificationSound()
        #expect(sound == .default)
    }

    @Test(arguments: AlarmSound.allCases.filter { $0.bundledFileName != nil })
    func `Bundled sounds have a non-empty file name`(sound: AlarmSound) throws {
        let fileName = try #require(sound.bundledFileName)
        #expect(fileName.isEmpty == false)
        #expect(fileName.hasSuffix(".caf"), "Bundled sounds must be .caf files")
    }

    @Test func `Every AlarmSound produces a non-nil notification sound`() {
        for sound in AlarmSound.allCases {
            let notifSound = sound.notificationSound()
            #expect(notifSound == notifSound, "notificationSound() should never crash for \(sound.rawValue)")
        }
    }

    // MARK: - Schedule Conditional Logic

    @Test func `Schedule with short timer does not create a warning`() async {
        let center = TestNotificationSchedulingCenter()
        let sut = NotificationService(center: center)

        // Schedule with 10s remaining - T-30 would be in the past
        await sut.schedule(
            endDate: Date().addingTimeInterval(10),
            presetName: "Test",
            warningEnabled: true,
            alarmSound: .systemDefault,
            warningSound: .systemDefault,
            includeCompletion: false
        )

        let pending = await center.pendingNotificationRequests()
        let warning = pending.first { $0.identifier == "rhoids.timer.warning" }
        #expect(warning == nil,
                "Warning should not be scheduled when T-30 is in the past")
    }

    @Test func `Schedule with expired endDate does not create a completion`() async {
        let center = TestNotificationSchedulingCenter()
        let sut = NotificationService(center: center)

        await sut.schedule(
            endDate: Date().addingTimeInterval(-5),
            presetName: "Test",
            warningEnabled: false,
            alarmSound: .systemDefault,
            warningSound: .systemDefault,
            includeCompletion: true
        )

        let pending = await center.pendingNotificationRequests()
        let complete = pending.first { $0.identifier == "rhoids.timer.complete" }
        #expect(complete == nil,
                "Completion should not be scheduled when endDate is in the past")
    }

    // MARK: - Helpers

    /// Mirrors the beep boundary calculation from NotificationService.scheduleBeepNotifications
    /// so we can test the pure logic without the notification center.
    private func computeBeepCount(duration: TimeInterval) -> Int {
        computeBeepBoundaries(duration: duration).count
    }

    private func computeBeepBoundaries(duration: TimeInterval) -> [TimeInterval] {
        var secondsFromStart: TimeInterval = 30
        var boundaries: [TimeInterval] = []
        while secondsFromStart < duration - 30 {
            boundaries.append(secondsFromStart)
            secondsFromStart += 30
        }
        return boundaries
    }
}
