import SwiftUI
import os.log

private let log = Logger(subsystem: "com.wesley.RHOIDS.watch", category: "App")

@main
struct RHOIDSWatchApp: App {
    @State private var appState = WatchAppState()
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    var body: some Scene {
        WindowGroup {
            WatchHomeView(appState: appState)
                .preferredColorScheme(colorScheme)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func handleDeepLink(_ url: URL) {
        log.debug("deep link: \(url)")
        switch url.host {
        case "start":
            // Return to home, ready to start
            appState.showTimer = false
        case "timer":
            // Show timer if one is actually running
            Task {
                let running = await appState.timerService.isRunning
                if running {
                    appState.showTimer = true
                }
            }
        default:
            break
        }
    }
}

// MARK: - App State Container

/// Single source of truth for app-level state, passed down the view hierarchy.
/// Avoids the computed-property pitfall of recreating services on each access.
@Observable
@MainActor
final class WatchAppState {
    let connectivityService: WatchConnectivityService
    let timerService: WatchTimerService
    var showTimer = false

    init() {
        let connectivity = WatchConnectivityService()
        self.connectivityService = connectivity
        self.timerService = WatchTimerService(connectivityService: connectivity)
    }
}
