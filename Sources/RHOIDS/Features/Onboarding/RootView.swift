import SwiftUI

/// Top‑level scene root. Handles first‑launch detection and the
/// splash → onboarding → main app transition.
struct RootView: View {
    enum Phase: Equatable {
        case splash
        case onboarding
        case main
    }

    /// Storage key. Exposed as a string constant for the QA reset helper.
    static let onboardedKey = "hasOnboarded.v1"

    /// Set the env var `FORCE_ONBOARDING=1` (Xcode → Edit Scheme → Run → Arguments
    /// → Environment Variables) to always show onboarding for QA / screenshots.
    private static var forceOnboarding: Bool {
        ProcessInfo.processInfo.environment["FORCE_ONBOARDING"] == "1"
    }

    #if DEBUG
    /// Set the env var `AUTO_START_TIMER=1` to skip straight to the main app and
    /// immediately start a default timer on launch. Used for headless QA of Live
    /// Activities across simulator models (capture the `[LiveActivity]` console
    /// logs). DEBUG-only - compiled out of release builds.
    private static var autoStartTimer: Bool {
        ProcessInfo.processInfo.environment["AUTO_START_TIMER"] == "1"
    }
    #endif

    @AppStorage(RootView.onboardedKey) private var hasOnboarded = false
    @State private var phase: Phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    #if DEBUG
    @State private var didAutoStart = false
    #endif

    let services: AppServices

    init(services: AppServices) {
        self.services = services
        #if DEBUG
        _phase = State(initialValue: Self.autoStartTimer ? .main : .splash)
        #else
        _phase = State(initialValue: .splash)
        #endif
    }

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView(
                    showGetStarted: needsOnboarding,
                    onComplete: {
                        transition(to: needsOnboarding ? .onboarding : .main)
                    }
                )
                .transition(.opacity)

            case .onboarding:
                OnboardingView(
                    notificationPermissionService: services.notificationPermissionService,
                    notificationService: services.notificationService,
                    screenTimeService: services.screenTimeService,
                    onFinish: {
                        hasOnboarded = true
                        transition(to: .main)
                    }
                )
                .transition(.opacity)

            case .main:
                ContentView(services: services)
                    .transition(.opacity)
            }
        }
        .animation(AppMotion.reveal(reduceMotion: reduceMotion), value: phase)
        #if DEBUG
        .task {
            guard Self.autoStartTimer, !didAutoStart else { return }
            didAutoStart = true
            let preset = PresetPreferences.defaultPreset
            let prefs = TimerService.TimerPreferences.current()
            await services.timerService.start(
                duration: preset.duration,
                preset: preset,
                preferences: prefs
            )
        }
        #endif
    }

    private var needsOnboarding: Bool {
        Self.forceOnboarding || !hasOnboarded
    }

    private func transition(to next: Phase) {
        phase = next
    }
}

// MARK: - QA helpers

extension RootView {
    /// Call from the LLDB console (`expr RootView.resetOnboarding()`) or from a
    /// debug menu to re‑show the onboarding flow on the next launch.
    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: onboardedKey)
    }
}

#if DEBUG
#Preview {
    RootView(services: .preview)
}
#endif
