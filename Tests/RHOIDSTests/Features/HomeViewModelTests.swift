import Testing
import Foundation
@testable import RHOIDS

@MainActor
struct HomeViewModelTests {
    /// Runs `body` against a fresh, isolated UserDefaults suite so tests can
    /// execute in parallel without sharing global state.
    private func withIsolatedDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "test-homevm-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    // MARK: - Constants

    @Test func `Min duration is 60 seconds`() throws {
        #expect(HomeViewModel.minDuration == 60)
    }

    @Test func `Max duration is 30 minutes`() throws {
        #expect(HomeViewModel.maxDuration == 30 * 60)
    }

    @Test func `Default duration is 3 minutes`() throws {
        #expect(HomeViewModel.defaultDuration == 180)
    }

    @Test func `Default duration is within min-max range`() throws {
        #expect(HomeViewModel.defaultDuration >= HomeViewModel.minDuration)
        #expect(HomeViewModel.defaultDuration <= HomeViewModel.maxDuration)
    }

    // MARK: - Init

    @Test func `Init uses default duration when nothing is stored`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            #expect(sut.customDuration == HomeViewModel.defaultDuration)
        }
    }

    @Test func `Init loads valid stored duration`() throws {
        try withIsolatedDefaults { defaults in
            defaults.set(120.0, forKey: UserPreferences.lastCustomDurationKey)
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            #expect(sut.customDuration == 120)
        }
    }

    @Test func `Init falls back to default when stored value is below min`() throws {
        try withIsolatedDefaults { defaults in
            defaults.set(10.0, forKey: UserPreferences.lastCustomDurationKey)
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            #expect(sut.customDuration == HomeViewModel.defaultDuration)
        }
    }

    @Test func `Init falls back to default when stored value is above max`() throws {
        try withIsolatedDefaults { defaults in
            defaults.set(99999.0, forKey: UserPreferences.lastCustomDurationKey)
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            #expect(sut.customDuration == HomeViewModel.defaultDuration)
        }
    }

    @Test func `Init falls back to default when stored value is zero`() throws {
        try withIsolatedDefaults { defaults in
            defaults.set(0.0, forKey: UserPreferences.lastCustomDurationKey)
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            #expect(sut.customDuration == HomeViewModel.defaultDuration)
        }
    }

    // MARK: - Custom Duration Clamping

    @Test func `Setting customDuration below min clamps to min`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = 10
            #expect(sut.customDuration == HomeViewModel.minDuration)
        }
    }

    @Test func `Setting customDuration above max clamps to max`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = 99999
            #expect(sut.customDuration == HomeViewModel.maxDuration)
        }
    }

    @Test func `Setting customDuration within range is accepted`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = 300
            #expect(sut.customDuration == 300)
        }
    }

    @Test func `Setting customDuration persists to UserDefaults`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = 240
            let stored = defaults.double(forKey: UserPreferences.lastCustomDurationKey)
            #expect(stored == 240)
        }
    }

    // MARK: - Custom Minutes

    @Test func `customMinutes getter converts seconds to minutes`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = 300
            #expect(sut.customMinutes == 5)
        }
    }

    @Test func `customMinutes setter converts minutes to seconds`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customMinutes = 10
            #expect(sut.customDuration == 600)
        }
    }

    @Test func `customMinutes setter clamps via customDuration`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customMinutes = 0
            #expect(sut.customDuration == HomeViewModel.minDuration,
                    "0 minutes = 0 seconds, should clamp to minDuration")
        }
    }

    // MARK: - Start Preset

    @Test func `startPreset falls back to default when no preset is selected`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.selectedPreset = nil
            #expect(sut.startPreset == PresetPreferences.defaultPreset)
        }
    }

    @Test func `startPreset uses selected preset when set`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            let max = PresetTimer.all.first { $0.name == "Max" }
            sut.selectedPreset = max
            #expect(sut.startPreset == max)
        }
    }

    // MARK: - Initial State

    @Test func `shouldShowTimer starts as false`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            #expect(sut.shouldShowTimer == false)
        }
    }

    @Test func `selectedPreset starts as nil`() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            #expect(sut.selectedPreset == nil)
        }
    }
}
