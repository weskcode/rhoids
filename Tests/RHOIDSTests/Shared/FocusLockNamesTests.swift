import Testing
import DeviceActivity
import ManagedSettings
@testable import RHOIDS

struct FocusLockNamesTests {
    @Test func `DeviceActivityName has a stable raw value`() {
        let name = DeviceActivityName.focusLockCooldown
        #expect(name.rawValue == "com.wesley.RHOIDS.focusLockCooldown",
                "Changing this identifier would orphan any in-flight cooldown monitors")
    }

    @Test func `ManagedSettingsStore name has a stable raw value`() {
        let name = ManagedSettingsStore.Name.focusLock
        #expect(name.rawValue == "com.wesley.RHOIDS.focusLock",
                "Changing this identifier would orphan persisted shield settings")
    }

    @Test func `Names use reverse-DNS format`() {
        #expect(DeviceActivityName.focusLockCooldown.rawValue.hasPrefix("com.wesley.RHOIDS."),
                "Activity name should use the app's reverse-DNS prefix")
        #expect(ManagedSettingsStore.Name.focusLock.rawValue.hasPrefix("com.wesley.RHOIDS."),
                "Store name should use the app's reverse-DNS prefix")
    }
}
