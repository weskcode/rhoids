import Foundation

/// Coordinates Apple's native App Store review opportunity after the user has
/// received meaningful value from RHOIDS. There is intentionally no custom
/// sentiment gate: every eligible user follows the same StoreKit path.
@MainActor
@Observable
final class ReviewPromptService {
    var shouldRequestReview = false

    static let minimumCompletedTimers = 3
    static let minimumActiveDays = 2
    static let requestCooldown: TimeInterval = 120 * 24 * 60 * 60

    static let completedTimerCountKey = "review.completedTimerCount.v2"
    static let activeDayStartsKey = "review.activeDayStarts.v2"
    static let lastRequestDateKey = "review.lastRequestDate.v2"

    private let defaults: UserDefaults
    private let calendar: Calendar
    private var hasPreparedRequestThisSession = false

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    /// Records a naturally completed timer. Cancelled timers never call this.
    func recordSuccessfulTimer(at date: Date = .now) {
        defaults.set(completedTimerCount + 1, forKey: Self.completedTimerCountKey)

        let dayStart = calendar.startOfDay(for: date).timeIntervalSince1970
        var days = activeDayStarts
        if !days.contains(dayStart) {
            days.append(dayStart)
            defaults.set(days.sorted(), forKey: Self.activeDayStartsKey)
        }
    }

    /// Called after the timer-completion sheet is dismissed, when no alarm or
    /// primary task is competing for attention. StoreKit may still decide not
    /// to display a prompt, which is expected platform behavior.
    func prepareReviewRequestIfEligible(now: Date = .now) {
        guard !hasPreparedRequestThisSession,
              completedTimerCount >= Self.minimumCompletedTimers,
              activeDayStarts.count >= Self.minimumActiveDays,
              isOutsideCooldown(now: now)
        else { return }

        hasPreparedRequestThisSession = true
        shouldRequestReview = true
    }

    /// Marks the cooldown only when the app is about to invoke StoreKit. A
    /// queued request that is lost to termination therefore remains eligible.
    func consumeReviewRequest(at now: Date = .now) -> Bool {
        guard shouldRequestReview else { return false }
        shouldRequestReview = false
        defaults.set(now, forKey: Self.lastRequestDateKey)
        return true
    }

    var completedTimerCount: Int {
        defaults.integer(forKey: Self.completedTimerCountKey)
    }

    var activeDayCount: Int {
        activeDayStarts.count
    }

    private var activeDayStarts: [TimeInterval] {
        defaults.array(forKey: Self.activeDayStartsKey) as? [TimeInterval] ?? []
    }

    private func isOutsideCooldown(now: Date) -> Bool {
        guard let lastRequest = defaults.object(forKey: Self.lastRequestDateKey) as? Date else {
            return true
        }
        return now.timeIntervalSince(lastRequest) >= Self.requestCooldown
    }
}
