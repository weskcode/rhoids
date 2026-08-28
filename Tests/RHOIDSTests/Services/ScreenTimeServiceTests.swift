import Testing
import Foundation
import FamilyControls
@testable import RHOIDS

/// Each test builds a `FocusLockPreferences` over a fresh, per-test
/// `UserDefaults` suite and injects it into the `ScreenTimeService` under test.
/// Because the suite is unique per test, state never leaks between tests or
/// into the shared App Group - no save/clear/restore dance is needed, and async
/// tests that suspend on `await` can no longer race a concurrent suite on the
/// shared `focusLockEnabled` key.
@MainActor
struct ScreenTimeServiceTests {
    private func freshPreferences() -> FocusLockPreferences {
        FocusLockPreferences(suiteName: "com.test.rhoids.screentime-\(UUID().uuidString)")
    }

    // MARK: - Initial State

    @Test func `Fresh service starts with empty selection`() {
        let prefs = freshPreferences()
        let sut = ScreenTimeService(preferences: prefs)
        #expect(sut.selection.applicationTokens.isEmpty)
        #expect(sut.selection.categoryTokens.isEmpty)
    }

    @Test func `Fresh service starts with shields inactive`() {
        let prefs = freshPreferences()
        let sut = ScreenTimeService(preferences: prefs)
        #expect(sut.shieldsActive == false)
    }

    @Test func `Init reads shields-active from preferences`() {
        let prefs = freshPreferences()
        prefs.shieldsActive = true
        prefs.cooldownEndDate = Date.now.addingTimeInterval(60)
        let sut = ScreenTimeService(preferences: prefs)
        #expect(sut.shieldsActive == true,
                "Init should hydrate shieldsActive from persisted state")
    }

    @Test func `Init clears legacy active shield without a cooldown deadline`() {
        let prefs = freshPreferences()
        prefs.shieldsActive = true
        prefs.cooldownEndDate = nil

        let sut = ScreenTimeService(preferences: prefs)

        #expect(sut.shieldsActive == false)
        #expect(prefs.shieldsActive == false)
    }

    @Test func `Init loads saved selection from preferences`() {
        let prefs = freshPreferences()
        let saved = FamilyActivitySelection()
        prefs.selection = saved
        let sut = ScreenTimeService(preferences: prefs)
        #expect(sut.selection == saved)
    }

    // MARK: - Selection Persistence

    @Test func `saveSelection persists current selection to preferences`() {
        let prefs = freshPreferences()
        let sut = ScreenTimeService(preferences: prefs)
        sut.saveSelection()
        let loaded = prefs.selection
        #expect(loaded != nil, "saveSelection should write to FocusLockPreferences")
    }

    @Test func `clearSelection resets in-memory and persisted selection`() {
        let prefs = freshPreferences()
        let sut = ScreenTimeService(preferences: prefs)
        prefs.selection = FamilyActivitySelection()
        sut.clearSelection()
        #expect(sut.selection.applicationTokens.isEmpty)
        #expect(sut.selection.categoryTokens.isEmpty)
        #expect(prefs.selection == nil,
                "clearSelection should remove persisted selection")
    }

    @Test func `loadSelection is a no-op when nothing is persisted`() {
        let prefs = freshPreferences()
        let sut = ScreenTimeService(preferences: prefs)
        let before = sut.selection
        prefs.selection = nil
        sut.loadSelection()
        #expect(sut.selection == before,
                "loadSelection should not change the in-memory selection when nothing is saved")
    }

    // MARK: - Shield Guards

    @Test func `applyShields is a no-op when Focus Lock is disabled`() {
        let prefs = freshPreferences()
        prefs.isEnabled = false
        let sut = ScreenTimeService(preferences: prefs)
        sut.applyShields()
        #expect(sut.shieldsActive == false,
                "Shields must not activate when Focus Lock is disabled")
    }

    @Test func `applyShields is a no-op when no selection is saved`() {
        let prefs = freshPreferences()
        prefs.isEnabled = true
        prefs.selection = nil
        let sut = ScreenTimeService(preferences: prefs)
        sut.applyShields()
        #expect(sut.shieldsActive == false,
                "Shields must not activate without a saved selection")
    }

    @Test func `applyShields is a no-op when selection has no apps or categories`() {
        let prefs = freshPreferences()
        prefs.isEnabled = true
        prefs.selection = FamilyActivitySelection()
        let sut = ScreenTimeService(preferences: prefs)
        sut.applyShields()
        #expect(sut.shieldsActive == false,
                "Shields must not activate with an empty app/category selection")
    }

    @Test func `applyShields preserves an existing valid cooldown`() {
        let prefs = freshPreferences()
        let deadline = Date.now.addingTimeInterval(120)
        prefs.isEnabled = true
        prefs.shieldsActive = true
        prefs.cooldownEndDate = deadline
        let sut = ScreenTimeService(preferences: prefs)

        sut.applyShields()

        #expect(sut.shieldsActive)
        #expect(prefs.shieldsActive)
        #expect(prefs.cooldownEndDate == deadline)
    }

    // MARK: - Remove Shields

    @Test func `removeShields clears in-memory and persisted active state`() {
        let prefs = freshPreferences()
        prefs.shieldsActive = true
        let sut = ScreenTimeService(preferences: prefs)
        sut.removeShields()
        #expect(sut.shieldsActive == false)
        #expect(prefs.shieldsActive == false)
    }

    @Test func `Stopping bathroom monitoring clears pending shield intent`() {
        let prefs = freshPreferences()
        prefs.bathroomSessionShouldShield = true
        let sut = ScreenTimeService(preferences: prefs)

        sut.stopBathroomSessionMonitoring()

        #expect(prefs.bathroomSessionShouldShield == false)
    }

    // MARK: - Refresh State

    @Test func `refreshShieldsActiveState syncs from preferences`() {
        let prefs = freshPreferences()
        let sut = ScreenTimeService(preferences: prefs)

        prefs.shieldsActive = true
        sut.refreshShieldsActiveState()
        #expect(sut.shieldsActive == true)

        prefs.shieldsActive = false
        sut.refreshShieldsActiveState()
        #expect(sut.shieldsActive == false)
    }

    @Test func `refresh removes shields after persisted cooldown deadline`() {
        let prefs = freshPreferences()
        prefs.shieldsActive = true
        prefs.cooldownEndDate = Date.now.addingTimeInterval(-1)
        let sut = ScreenTimeService(preferences: prefs)

        sut.refreshShieldsActiveState()

        #expect(sut.shieldsActive == false)
        #expect(prefs.shieldsActive == false)
        #expect(prefs.cooldownEndDate == nil)
    }

    // MARK: - Revoke Authorization

    @Test func `revokeAuthorization resets all Focus Lock state`() async {
        let prefs = freshPreferences()
        prefs.isEnabled = true
        prefs.shieldsActive = true
        let sut = ScreenTimeService(preferences: prefs)

        await sut.revokeAuthorization()

        #expect(sut.authorizationStatus == .notDetermined)
        #expect(prefs.isEnabled == false,
                "Revoke should disable Focus Lock")
        #expect(sut.shieldsActive == false)
        #expect(prefs.shieldsActive == false)
    }

    @Test func `revokeAuthorization clears saved selection`() async {
        let prefs = freshPreferences()
        prefs.selection = FamilyActivitySelection()
        let sut = ScreenTimeService(preferences: prefs)

        await sut.revokeAuthorization()

        #expect(sut.selection.applicationTokens.isEmpty)
        #expect(sut.selection.categoryTokens.isEmpty)
    }
}
