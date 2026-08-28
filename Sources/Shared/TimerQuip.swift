import Foundation

struct TimerQuip: Identifiable, Sendable {
    let id = UUID()
    let body: String
}

extension TimerQuip {
    /// Played when the timer runs out naturally.
    static let completionQuips: [TimerQuip] = [
        TimerQuip(body: String(localized: "Your colon sent its regards.")),
        TimerQuip(body: String(localized: "Hemorrhoids hate this one weird trick.")),
        TimerQuip(body: String(localized: "Stand up. Your veins are watching.")),
        TimerQuip(body: String(localized: "You sat. You scrolled. You survived.")),
        TimerQuip(body: String(localized: "Bowels of glory. Doors of victory.")),
        TimerQuip(body: String(localized: "Step away from the throne, peasant.")),
        TimerQuip(body: String(localized: "Five more minutes is how it always starts.")),
        TimerQuip(body: String(localized: "Mission complete. Cheeks intact.")),
        TimerQuip(body: String(localized: "Doctor's orders: walk it off.")),
        TimerQuip(body: String(localized: "Your future self just high-fived you."))
    ]

    /// Played when the user stops the timer early - they're a champ for leaving on time.
    static let earlyStopQuips: [TimerQuip] = [
        TimerQuip(body: String(localized: "Good job! You made it under the time.")),
        TimerQuip(body: String(localized: "Quick exit. Your veins approve.")),
        TimerQuip(body: String(localized: "In and out. Olympic form.")),
        TimerQuip(body: String(localized: "Speed run complete. Bowels intact.")),
        TimerQuip(body: String(localized: "You knew when to leave. Respect.")),
        TimerQuip(body: String(localized: "Efficiency: certified.")),
        TimerQuip(body: String(localized: "Short visit, long-term win."))
    ]

    /// Rotating messages for the every-30-second beep notifications.
    /// Key message: don't push, don't rush, relax - come back later if needed.
    static let beepQuips: [TimerQuip] = [
        TimerQuip(body: String(localized: "Relax. Don't push. Let it happen naturally.")),
        TimerQuip(body: String(localized: "No rushing. If it's not happening, that's okay.")),
        TimerQuip(body: String(localized: "Breathe. Straining causes the exact thing we're preventing.")),
        TimerQuip(body: String(localized: "Stay relaxed. You can always come back later.")),
        TimerQuip(body: String(localized: "Gentle reminder: pushing = hemorrhoids. Don't do it.")),
        TimerQuip(body: String(localized: "Take it easy. Your body works on its own schedule.")),
        TimerQuip(body: String(localized: "Not done yet? No stress. Walk away and try again later.")),
        TimerQuip(body: String(localized: "Patience over pressure. Your veins will thank you.")),
    ]

    /// Message for the T-30 warning - time is almost up, but don't panic.
    static let warningQuips: [TimerQuip] = [
        TimerQuip(body: String(localized: "30 seconds left. Don't rush. Just start wrapping up.")),
        TimerQuip(body: String(localized: "Almost done. If you're not finished, come back later.")),
        TimerQuip(body: String(localized: "30 seconds. No pushing! You can always try again.")),
        TimerQuip(body: String(localized: "Time's nearly up. Relax. Forcing it does more harm.")),
        TimerQuip(body: String(localized: "Wrapping up soon. Remember: never strain.")),
        TimerQuip(body: String(localized: "30 seconds left. It's okay to walk away unfinished.")),
    ]

    static func randomCompletion() -> TimerQuip {
        completionQuips.randomElement() ?? completionQuips[0]
    }

    static func randomEarlyStop() -> TimerQuip {
        earlyStopQuips.randomElement() ?? earlyStopQuips[0]
    }

    static func randomBeep() -> TimerQuip {
        beepQuips.randomElement() ?? beepQuips[0]
    }

    static func randomWarning() -> TimerQuip {
        warningQuips.randomElement() ?? warningQuips[0]
    }
}
