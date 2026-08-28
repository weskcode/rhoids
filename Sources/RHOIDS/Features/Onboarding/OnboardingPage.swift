import Foundation

struct OnboardingFeature: Identifiable, Sendable {
    let id = UUID()
    let symbol: String
    let title: String
    let description: String
}

struct OnboardingPage: Identifiable, Sendable {
    let id = UUID()
    let heroSymbol: String
    let title: String
    let subtitle: String
    let features: [OnboardingFeature]
}

extension OnboardingPage {
    static let all: [OnboardingPage] = [
        .theRule,
        .focusMode,
        .notifications,
        .makeItStick
    ]

    static let theRule = OnboardingPage(
        heroSymbol: "stopwatch.fill",
        title: String(localized: "The 5-Minute Rule"),
        subtitle: String(localized: "Doctors say 3 to 5 minutes max on the toilet."),
        features: [
            OnboardingFeature(
                symbol: "chart.bar.fill",
                title: String(localized: "1 in 4 adults are affected"),
                description: String(localized: "Sitting too long is the #1 preventable cause.")
            ),
            OnboardingFeature(
                symbol: "iphone.gen3",
                title: String(localized: "Phones make it worse"),
                description: String(localized: "Scrolling on the toilet raises the risk by 46%.")
            ),
            OnboardingFeature(
                symbol: "book.closed.fill",
                title: String(localized: "Want the full science?"),
                description: String(localized: "Check the Science page in Settings. All the research is there.")
            )
        ]
    )

    static let focusMode = OnboardingPage(
        heroSymbol: "iphone.slash",
        title: String(localized: "Pick Your Style"),
        subtitle: String(localized: "How should RHOIDS help you put the phone down?"),
        features: []
    )

    static let notifications = OnboardingPage(
        heroSymbol: "bell.badge.fill",
        title: String(localized: "Never Miss It"),
        subtitle: String(localized: "Timer alerts you control, never marketing."),
        features: [
            OnboardingFeature(
                symbol: "speaker.wave.3.fill",
                title: String(localized: "Reliable Timer Alerts"),
                description: String(localized: "Get a completion alert, with an optional 30-second warning. Full-screen alarms request separate permission when you start a timer.")
            ),
            OnboardingFeature(
                symbol: "hand.raised.fill",
                title: String(localized: "No spam, ever"),
                description: String(localized: "Daily reminders are off by default and only turn on when you choose them in Settings.")
            )
        ]
    )

    static let makeItStick = OnboardingPage(
        heroSymbol: "target",
        title: String(localized: "Make It Stick"),
        subtitle: String(localized: "The best timer is the one you actually use."),
        features: [
            OnboardingFeature(
                symbol: "square.grid.2x2",
                title: String(localized: "Add the widget"),
                description: String(localized: "Put RHOIDS on your Home Screen. One tap starts the timer. No app to open.")
            ),
            OnboardingFeature(
                symbol: "apps.iphone",
                title: String(localized: "Move the app icon"),
                description: String(localized: "Place RHOIDS next to social media, news, or games, the apps you reach for on the toilet.")
            ),
            OnboardingFeature(
                symbol: "applewatch",
                title: String(localized: "Apple Watch"),
                description: String(localized: "Already installed. Start timers from your wrist.")
            )
        ]
    )
}
