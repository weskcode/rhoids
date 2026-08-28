import Testing
import Foundation
@testable import RHOIDS

struct AlarmKitServiceTests {
    @Test func `Active ID key is stable`() {
        #expect(AlarmKitService.activeIDKey == "activeAlarmKitID",
                "Changing this key would orphan any in-flight alarms")
    }

    @Test func `Suite name matches shared state`() {
        #expect(AlarmKitService.suiteName == SharedStateKeys.suiteName)
    }

    @Test func `scheduleTimer returns nil on simulator`() async {
        let sut = AlarmKitService()
        let result = await sut.scheduleTimer(duration: 180, presetName: "Test")
        #expect(result == nil,
                "Simulator has no AlarmKit daemons - schedule should return nil")
    }

    @Test func `isAuthorized returns false on simulator`() async {
        let sut = AlarmKitService()
        let authorized = await sut.isAuthorized
        #expect(authorized == false,
                "Simulator has no AlarmKit - should always be unauthorized")
    }

    @Test func `cancelActive is safe with no active alarm`() async {
        let sut = AlarmKitService()
        await sut.cancelActive()
    }

    // MARK: - QA: Manual On-Device AlarmKit Verification
    //
    // The following scenarios MUST be verified manually on a physical device:
    //
    // 1. Timer completion interrupts other apps:
    //    - Start a timer, switch to Safari, wait for alarm to fire
    //    - Expected: Full-screen alarm appears over Safari
    //
    // 2. AlarmKit fires through Silent switch:
    //    - Enable Silent mode via hardware switch
    //    - Start a timer and wait for completion
    //    - Expected: Alarm sound plays through Silent mode
    //
    // 3. AlarmKit fires through Focus mode:
    //    - Enable Do Not Disturb or a custom Focus
    //    - Start a timer and wait for completion
    //    - Expected: Alarm breaks through Focus restrictions
    //
    // 4. 30-second warning banner appears when backgrounded:
    //    - Set warning to "End Only" mode
    //    - Start a 2-minute timer, switch to Home screen
    //    - Expected: Banner notification at T-30
    //
    // 5. Recurring warnings fire when backgrounded:
    //    - Set warning to "Every 30 Seconds" mode
    //    - Start a 3-minute timer, switch to Home screen
    //    - Expected: Banner every 30s (150s, 120s, 90s, 60s, 30s marks)
    //
    // 6. AlarmKit + notification don't double-alert:
    //    - Start timer with both AlarmKit authorized and notifications enabled
    //    - Expected: AlarmKit fires full-screen alarm, no duplicate UN notification
}
