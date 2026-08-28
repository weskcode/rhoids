import Foundation

enum DurationFormatter {
    static func formatted(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if totalSeconds < 60 {
            return "\(totalSeconds) sec"
        } else if seconds == 0 {
            return "\(minutes) min"
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
