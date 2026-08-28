import SwiftUI
import SwiftData

@main
struct RHOIDSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var services = AppServices()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
                .modelContainer(for: TimerSession.self)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}
