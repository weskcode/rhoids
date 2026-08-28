import SwiftUI
import StoreKit

struct ContentView: View {
    let services: AppServices
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        TabView {
            Tab("Timer", systemImage: "timer") {
                HomeView(services: services)
            }
            Tab("History", systemImage: "list.bullet") {
                HistoryView(dailyUseTracker: services.dailyUseTracker)
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView(
                    screenTimeService: services.screenTimeService,
                    tipJarService: services.tipJarService,
                    notificationService: services.notificationService
                )
            }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            switch newPhase {
            case .active:
                handleAppOpen()
            case .background:
                services.appOpenTracker.sceneDidEnterBackground()
            default:
                break
            }
        }
        .onChange(of: services.reviewPromptService.shouldRequestReview) { _, wantsReview in
            guard wantsReview else { return }
            requestNativeReviewIfReady()
        }
    }

    /// Counts a real foreground session and daily use without interrupting
    /// launch with permission or review alerts.
    private func handleAppOpen() {
        _ = services.appOpenTracker.registerOpenIfNeeded()
        services.dailyUseTracker.registerUse()
        requestNativeReviewIfReady()
    }

    /// Gives the completion sheet and timer transition time to finish before
    /// StoreKit is invoked. If the app backgrounds, the request remains queued
    /// until the next active scene instead of burning the opportunity.
    private func requestNativeReviewIfReady() {
        guard scenePhase == .active,
              services.reviewPromptService.shouldRequestReview
        else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard scenePhase == .active,
                  services.reviewPromptService.consumeReviewRequest()
            else { return }
            requestReview()
        }
    }
}

#if DEBUG
#Preview {
    ContentView(services: .preview)
}
#endif
