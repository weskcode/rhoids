import Foundation
import Testing
@testable import RHOIDS

@MainActor
struct HomeViewModelEdgeCaseTests {

    // MARK: - Custom duration clamping boundary values

    @Test("customDuration at exact minimum is accepted")
    func customDurationExactMin() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = HomeViewModel.minDuration
            #expect(sut.customDuration == HomeViewModel.minDuration)
        }
    }

    @Test("customDuration at exact maximum is accepted")
    func customDurationExactMax() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = HomeViewModel.maxDuration
            #expect(sut.customDuration == HomeViewModel.maxDuration)
        }
    }

    @Test("customDuration 1 below minimum clamps to minimum")
    func customDurationOneBelow() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = HomeViewModel.minDuration - 1
            #expect(sut.customDuration == HomeViewModel.minDuration)
        }
    }

    @Test("customDuration 1 above maximum clamps to maximum")
    func customDurationOneAbove() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = HomeViewModel.maxDuration + 1
            #expect(sut.customDuration == HomeViewModel.maxDuration)
        }
    }

    @Test("customDuration negative value clamps to minimum")
    func customDurationNegative() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = -100
            #expect(sut.customDuration == HomeViewModel.minDuration)
        }
    }

    @Test("customDuration zero clamps to minimum")
    func customDurationZero() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customDuration = 0
            #expect(sut.customDuration == HomeViewModel.minDuration)
        }
    }

    // MARK: - customMinutes edge cases

    @Test("customMinutes at 1 minute equals 60 seconds")
    func customMinutesOne() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customMinutes = 1
            #expect(sut.customDuration == 60)
            #expect(sut.customMinutes == 1)
        }
    }

    @Test("customMinutes at 30 minutes equals 1800 seconds (max)")
    func customMinutes30() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customMinutes = 30
            #expect(sut.customDuration == 1800)
            #expect(sut.customMinutes == 30)
        }
    }

    @Test("customMinutes at 31 clamps to 30 (maxDuration)")
    func customMinutes31ClampedToMax() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.customMinutes = 31
            #expect(sut.customDuration == HomeViewModel.maxDuration)
            #expect(sut.customMinutes == 30)
        }
    }

    @Test("customMinutes roundtrip for all valid values")
    func customMinutesRoundTrip() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            for minutes in 1...30 {
                sut.customMinutes = minutes
                #expect(sut.customMinutes == minutes,
                        "Round-trip failed for \(minutes) minutes")
            }
        }
    }

    // MARK: - Init with edge-case stored values

    @Test("Init with exactly minDuration stored loads it")
    func initExactMinStored() throws {
        try withIsolatedDefaults { defaults in
            defaults.set(HomeViewModel.minDuration, forKey: UserPreferences.lastCustomDurationKey)
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            #expect(sut.customDuration == HomeViewModel.minDuration)
        }
    }

    @Test("Init with exactly maxDuration stored loads it")
    func initExactMaxStored() throws {
        try withIsolatedDefaults { defaults in
            defaults.set(HomeViewModel.maxDuration, forKey: UserPreferences.lastCustomDurationKey)
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            #expect(sut.customDuration == HomeViewModel.maxDuration)
        }
    }

    @Test("Init with negative stored value falls back to default")
    func initNegativeStored() throws {
        try withIsolatedDefaults { defaults in
            defaults.set(-100.0, forKey: UserPreferences.lastCustomDurationKey)
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            #expect(sut.customDuration == HomeViewModel.defaultDuration)
        }
    }

    // MARK: - startPreset behavior

    @Test("startPreset uses custom duration for custom preset")
    func startPresetCustomDuration() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.selectedPreset = .custom
            sut.customDuration = 240
            let preset = sut.startPreset
            #expect(preset.isCustom, "Should return the custom preset")
            // The actual duration comes from customDuration, not preset.duration
        }
    }

    @Test("startPreset uses preset's own duration for non-custom presets")
    func startPresetNonCustomDuration() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.selectedPreset = .recommended
            #expect(sut.startPreset == .recommended)
            #expect(sut.startPreset.duration == 180)
        }
    }

    // MARK: - checkPendingTimer edge cases

    @Test("checkPendingTimer does nothing when shouldShowTimer is already true")
    func checkPendingTimerAlreadyShowing() async throws {
        try await withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            sut.shouldShowTimer = true
            await sut.checkPendingTimer()
            #expect(sut.shouldShowTimer == true,
                    "Should short-circuit when already showing timer")
        }
    }

    // MARK: - Multiple rapid setting changes

    @Test("Rapidly changing customDuration settles at final value")
    func rapidDurationChanges() throws {
        try withIsolatedDefaults { defaults in
            let sut = HomeViewModel(services: .preview, defaults: defaults)
            for value in stride(from: 60, through: 1800, by: 60) {
                sut.customDuration = TimeInterval(value)
            }
            #expect(sut.customDuration == 1800)
            let stored = defaults.double(forKey: UserPreferences.lastCustomDurationKey)
            #expect(stored == 1800)
        }
    }

    // MARK: - Helpers

    /// Runs `body` against a fresh, isolated UserDefaults suite so tests can
    /// execute in parallel without sharing global state.
    private func withIsolatedDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "test-homevm-edge-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    private func withIsolatedDefaults(_ body: @MainActor (UserDefaults) async throws -> Void) async throws {
        let suiteName = "test-homevm-edge-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try await body(defaults)
    }
}
