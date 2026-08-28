import AppIntents

struct RHOIDSAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTimerIntent(),
            phrases: [
                "Start a \(.applicationName) timer",
                "Start the recommended \(.applicationName) timer",
                "Start \(.applicationName)"
            ],
            shortTitle: "Start Timer",
            systemImageName: "timer"
        )
        
        AppShortcut(
            intent: StopTimerIntent(),
            phrases: [
                "Stop my \(.applicationName) timer",
                "Stop \(.applicationName)"
            ],
            shortTitle: "Stop Timer",
            systemImageName: "stop.circle"
        )
    }
}
