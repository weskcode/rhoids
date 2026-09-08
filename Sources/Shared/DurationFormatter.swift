import Foundation

enum DurationFormatter {
    static func formatted(
        _ interval: TimeInterval,
        bundle: Bundle = .main,
        locale: Locale = .current
    ) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        // Localized: this string is the duration the user is choosing, and it
        // renders on the main screen, in History, and in a VoiceOver label. It
        // previously interpolated bare English ("3 min"), which shipped Latin
        // text into all twelve non-English locales.
        if totalSeconds < 60 {
            return String(
                localized: "\(totalSeconds) sec",
                bundle: bundle,
                locale: locale,
                comment: "Short duration in seconds, e.g. 45 sec"
            )
        } else if seconds == 0 {
            return String(
                localized: "\(minutes) min",
                bundle: bundle,
                locale: locale,
                comment: "Whole-minute duration, e.g. 3 min"
            )
        }
        // Digits only - no unit to translate. Left as-is deliberately so the
        // running countdown keeps a stable, compact shape in every locale.
        return String(format: "%d:%02d", minutes, seconds)
    }
}
