@preconcurrency import DeviceActivity
@preconcurrency import ManagedSettings
@preconcurrency import FamilyControls
import Foundation

// This extension can't import the main app target, so these mirror
// `Sources/Shared/FocusLockNames.swift` / `FocusLockPreferences.swift` by
// hardcoded string. `FocusLockConsistencyTests` catches drift between the two.

private extension DeviceActivityName {
    static let focusLockCooldown = DeviceActivityName("com.wesley.RHOIDS.focusLockCooldown")
    static let focusLockBathroomSession = DeviceActivityName("com.wesley.RHOIDS.focusLockBathroomSession")
}

private extension ManagedSettingsStore.Name {
    static let focusLock = ManagedSettingsStore.Name("com.wesley.RHOIDS.focusLock")
}

private enum FocusLockKey {
    static let enabled = "focusLockEnabled"
    static let selection = "focusLockSelection"
    static let cooldownDuration = "focusLockCooldown"
    static let shieldsActive = "focusLockShieldsActive"
    static let cooldownEndDate = "focusLockCooldownEndDate"
    static let mode = "focusLockMode"
    static let limitedScrollingRawValue = "limitedScrolling"
    static let bathroomSessionShouldShield = "focusLockBathroomSessionShouldShield"
}

/// Runs as its own process, independent of the host app's lifecycle - this
/// is what makes app blocking reliable even when RHOIDS is suspended in the
/// background (which is the expected state for Limited Scrolling: the user
/// is off using one of their allowed apps when the timer ends).
class FocusLockMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: .focusLock)

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.wesley.RHOIDS")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        switch activity {
        case .focusLockBathroomSession:
            guard defaults?.bool(forKey: FocusLockKey.bathroomSessionShouldShield) == true else {
                return
            }
            defaults?.set(false, forKey: FocusLockKey.bathroomSessionShouldShield)
            applyShieldFromSavedSelection()
        case .focusLockCooldown:
            clearCooldown()
        default:
            break
        }
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)

        switch activity {
        case .focusLockBathroomSession:
            guard defaults?.bool(forKey: FocusLockKey.bathroomSessionShouldShield) == true else {
                return
            }
            defaults?.set(false, forKey: FocusLockKey.bathroomSessionShouldShield)
            applyShieldFromSavedSelection()
            DeviceActivityCenter().stopMonitoring([.focusLockBathroomSession])
        case .focusLockCooldown:
            guard let deadline = defaults?.object(forKey: FocusLockKey.cooldownEndDate) as? Date,
                  deadline <= .now else { return }
            clearCooldown()
        default:
            break
        }
    }

    /// The bathroom timer just ended. Shield the saved app selection, then
    /// chain straight into the cooldown schedule so its end warning or
    /// `intervalDidEnd` callback clears it later.
    /// No-ops if the user isn't (or is no longer) set up for Limited
    /// Scrolling - Settings flips `focusLockEnabled`/`focusLockMode`
    /// immediately on any mid-session change, so this read always reflects
    /// the user's latest choice.
    private func applyShieldFromSavedSelection() {
        if defaults?.bool(forKey: FocusLockKey.shieldsActive) == true,
           let deadline = defaults?.object(forKey: FocusLockKey.cooldownEndDate) as? Date,
           deadline > .now {
            DeviceActivityCenter().stopMonitoring([.focusLockBathroomSession])
            return
        }

        guard defaults?.bool(forKey: FocusLockKey.enabled) == true,
              defaults?.string(forKey: FocusLockKey.mode) == FocusLockKey.limitedScrollingRawValue,
              let data = defaults?.data(forKey: FocusLockKey.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }

        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        guard !apps.isEmpty || !categories.isEmpty else { return }

        // Replace the prior selection exactly and discard any stale setting
        // left by an older build before starting this cooldown.
        store.clearAllSettings()
        if !apps.isEmpty {
            store.shield.applications = apps
        }
        if !categories.isEmpty {
            store.shield.applicationCategories = .specific(categories)
        }
        defaults?.set(true, forKey: FocusLockKey.shieldsActive)

        let stored = defaults?.double(forKey: FocusLockKey.cooldownDuration) ?? 0
        let cooldownDuration = stored > 0 ? stored : 300

        let now = Date.now
        defaults?.set(now.addingTimeInterval(cooldownDuration), forKey: FocusLockKey.cooldownEndDate)
        let plan = FocusLockActivitySchedule.make(startingAt: now, duration: cooldownDuration)

        do {
            try DeviceActivityCenter().startMonitoring(.focusLockCooldown, during: plan.schedule)
        } catch {
            // A shield without a registered cleanup callback can strand the
            // selected apps indefinitely. Fail open if scheduling is ever
            // rejected; the host app's already-scheduled encouragement can
            // still confirm that the apps are available.
            store.clearAllSettings()
            defaults?.set(false, forKey: FocusLockKey.shieldsActive)
            defaults?.removeObject(forKey: FocusLockKey.cooldownEndDate)
        }
    }

    private func clearCooldown() {
        store.clearAllSettings()
        defaults?.set(false, forKey: FocusLockKey.shieldsActive)
        defaults?.removeObject(forKey: FocusLockKey.cooldownEndDate)
        DeviceActivityCenter().stopMonitoring([.focusLockCooldown])
    }
}
