import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import os.log

/// The shielding behavior `TimerViewModel` depends on. Extracting a protocol
/// seam lets tests inject a spy to verify that Focus Lock shields are applied
/// on timer completion - the concrete `ScreenTimeService.applyShields()`
/// early-returns without real FamilyControls selection tokens, which aren't
/// available in a unit-test environment.

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "ScreenTime")

@MainActor
protocol ScreenTimeShielding {
    func applyShields()
}

/// The Device Activity scheduling `TimerService` depends on to make Limited
/// Scrolling's app-blocking reliable even when the host app is suspended.
/// `TimerService` schedules a `.focusLockBathroomSession` interval covering
/// the running timer at `start()`; `RHOIDSDeviceActivityMonitor` (a separate
/// process the system runs regardless of host-app state) applies the shield
/// at the timer deadline (using an end warning for sub-15-minute timers).
/// `stopBathroomSessionMonitoring()` is called
/// unconditionally on stop/cancel so an early-stopped timer can't shield
/// apps later at its original, now-invalid end time.
@MainActor
protocol ScreenTimeSessionScheduling: Sendable {
    func startBathroomSessionMonitoring(duration: TimeInterval)
    func stopBathroomSessionMonitoring()
}

@MainActor
@Observable
final class ScreenTimeService: ScreenTimeShielding, ScreenTimeSessionScheduling {
    var authorizationStatus: AuthorizationStatus = .notDetermined
    var selection = FamilyActivitySelection()
    var shieldsActive = false

    private let store = ManagedSettingsStore(named: .focusLock)
    private let preferences: FocusLockPreferences

    init(preferences: FocusLockPreferences = .shared) {
        self.preferences = preferences
        loadSelection()
        shieldsActive = preferences.shieldsActive
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus

        // Builds before cooldown deadlines were persisted can leave an
        // active shield with no safe way to know when it should expire.
        // Treat that legacy state as stale when the updated app next opens.
        if shieldsActive && preferences.cooldownEndDate == nil {
            removeShields()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func revokeAuthorization() async {
        authorizationStatus = .notDetermined
        preferences.isEnabled = false
        removeShields()
        clearSelection()
    }

    // MARK: - Shield Management

    func applyShields() {
        guard preferences.isEnabled else { return }
        if preferences.shieldsActive,
           let existingDeadline = preferences.cooldownEndDate,
           existingDeadline > .now {
            // This can be a duplicate call for the SAME cooldown, but it can
            // just as easily be a genuinely new bathroom session finishing
            // while an earlier one's cooldown is still counting down -
            // nothing in the UI blocks starting another Limited Scrolling
            // timer while a shield is already up. Extend the deadline
            // instead of silently discarding this session's chosen
            // cooldown, so the user is never unblocked sooner than either
            // session promised.
            shieldsActive = true
            extendCooldownIfNeeded(pastDeadline: existingDeadline)
            return
        }
        guard let saved = preferences.selection else { return }

        let apps = saved.applicationTokens
        let categories = saved.categoryTokens

        if apps.isEmpty && categories.isEmpty { return }

        // Always replace the previous selection exactly. This also clears
        // any legacy/stale setting before a new cooldown begins.
        store.clearAllSettings()
        if !apps.isEmpty {
            store.shield.applications = apps
        }
        if !categories.isEmpty {
            store.shield.applicationCategories = .specific(categories)
        }

        shieldsActive = true
        preferences.shieldsActive = true
        preferences.cooldownEndDate = Date.now.addingTimeInterval(preferences.cooldownDuration)
        log.debug("shields applied - \(apps.count) app(s), \(categories.count) category/categories")

        do {
            try startCooldown()
        } catch {
            log.error("failed to start cooldown: \(error)")
            // A shield without a registered cleanup callback can strand the
            // selected apps indefinitely. Fail open if scheduling is ever
            // rejected, while preserving normal cooldown behavior when the
            // valid schedule above succeeds.
            removeShields()
        }
    }

    func removeShields() {
        store.clearAllSettings()
        stopCooldown()
        shieldsActive = false
        preferences.shieldsActive = false
        preferences.cooldownEndDate = nil
        log.debug("shields removed")
    }

    // MARK: - Cooldown

    private func startCooldown() throws {
        let now = Date.now
        let plan = FocusLockActivitySchedule.make(
            startingAt: now,
            duration: preferences.cooldownDuration
        )

        let center = DeviceActivityCenter()
        try center.startMonitoring(.focusLockCooldown, during: plan.schedule)
        log.debug("cooldown started - \(Int(self.preferences.cooldownDuration))s")
    }

    private func stopCooldown() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.focusLockCooldown])
    }

    /// Whether extending the cooldown to a fresh `duration` from now would
    /// push the deadline later than `existingDeadline`. Pure decision logic,
    /// kept separate from the DeviceActivityCenter side effects below so it
    /// can be unit tested without touching real Screen Time APIs.
    static func extendedDeadline(pastDeadline existingDeadline: Date, duration: TimeInterval) -> Date? {
        let candidateDeadline = Date.now.addingTimeInterval(duration)
        return candidateDeadline > existingDeadline ? candidateDeadline : nil
    }

    /// Restarts cooldown monitoring for this session's chosen duration,
    /// timed from now, if doing so would push the deadline later than
    /// `existingDeadline`. No-ops (leaving the earlier cooldown ticking
    /// down untouched) for a genuine duplicate call where the "new"
    /// deadline would land at or before the existing one.
    private func extendCooldownIfNeeded(pastDeadline existingDeadline: Date) {
        guard let candidateDeadline = Self.extendedDeadline(
            pastDeadline: existingDeadline,
            duration: preferences.cooldownDuration
        ) else {
            log.debug("cooldown already active - preserving existing deadline")
            return
        }
        preferences.cooldownEndDate = candidateDeadline
        stopCooldown()
        do {
            try startCooldown()
        } catch {
            log.error("failed to extend cooldown: \(error)")
            // Extension failed, but the original (shorter) cooldown
            // monitoring was already stopped above - restore the stored
            // deadline to match what will actually clear the shield, and
            // try to re-arm monitoring for it rather than leaving nothing
            // watching the shield at all.
            preferences.cooldownEndDate = existingDeadline
            let fallbackPlan = FocusLockActivitySchedule.make(
                startingAt: .now,
                duration: existingDeadline.timeIntervalSinceNow
            )
            try? DeviceActivityCenter().startMonitoring(.focusLockCooldown, during: fallbackPlan.schedule)
        }
    }

    // MARK: - Bathroom Session Monitoring

    /// Schedules a Device Activity interval covering the running timer, so
    /// `FocusLockMonitor` can apply the shield at the timer deadline even if
    /// this process is suspended by then. No-op unless Limited Scrolling is
    /// actually configured - callers should already gate on
    /// `TimerService.TimerPreferences.focusLockBlockingWillEngage`, but this
    /// guard keeps the method safe to call unconditionally too.
    func startBathroomSessionMonitoring(duration: TimeInterval) {
        guard preferences.isEnabled, preferences.mode == .limitedScrolling else { return }

        let now = Date.now
        let plan = FocusLockActivitySchedule.make(startingAt: now, duration: duration)

        let center = DeviceActivityCenter()
        preferences.bathroomSessionShouldShield = true
        do {
            try center.startMonitoring(.focusLockBathroomSession, during: plan.schedule)
            log.debug("bathroom session monitoring started - \(Int(duration))s")
        } catch {
            preferences.bathroomSessionShouldShield = false
            log.error("failed to start bathroom session monitoring: \(error)")
        }
    }

    /// Cancels a pending bathroom-session schedule. Safe to call even when
    /// nothing is scheduled (early stop, mode switched away from Limited
    /// Scrolling mid-timer, etc).
    func stopBathroomSessionMonitoring() {
        preferences.bathroomSessionShouldShield = false
        let center = DeviceActivityCenter()
        center.stopMonitoring([.focusLockBathroomSession])
    }

    // MARK: - Selection Persistence

    func saveSelection() {
        preferences.selection = selection
        log.debug("selection saved - \(self.selection.applicationTokens.count) app(s), \(self.selection.categoryTokens.count) category/categories")
    }

    func loadSelection() {
        if let saved = preferences.selection {
            selection = saved
        }
    }

    func clearSelection() {
        selection = FamilyActivitySelection()
        preferences.selection = nil
    }

    func refreshShieldsActiveState() {
        if preferences.shieldsActive,
           let cooldownEndDate = preferences.cooldownEndDate,
           cooldownEndDate <= .now {
            removeShields()
            return
        }
        shieldsActive = preferences.shieldsActive
    }
}
