@preconcurrency import DeviceActivity
@preconcurrency import ManagedSettings

extension DeviceActivityName {
    static let focusLockCooldown = DeviceActivityName("com.wesley.RHOIDS.focusLockCooldown")
    static let focusLockBathroomSession = DeviceActivityName("com.wesley.RHOIDS.focusLockBathroomSession")
}

extension ManagedSettingsStore.Name {
    static let focusLock = ManagedSettingsStore.Name("com.wesley.RHOIDS.focusLock")
}
