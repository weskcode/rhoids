import Foundation

/// Counts "app opens": cold launches plus returns from the background.
/// The persisted count is available for product analytics and session-based
/// features, but it never drives review or notification permission prompts.
///
/// A foreground session counts as exactly one open: repeated `.active`
/// transitions (e.g. dismissing a system alert or Control Center) don't
/// inflate the count. Call `registerOpenIfNeeded()` on `.active` and
/// `sceneDidEnterBackground()` on `.background`.
@MainActor
@Observable
final class AppOpenTracker {

    static let openCountKey = "appOpenCount.v1"

    private let defaults: UserDefaults

    /// Armed at launch and re-armed on each background transition, so only
    /// the first `.active` transition per foreground session counts.
    private var isArmed = true

    private(set) var openCount: Int

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.openCount = defaults.integer(forKey: Self.openCountKey)
    }

    /// Counts a new open unless one was already counted since the last
    /// background transition. Returns the current open count either way.
    @discardableResult
    func registerOpenIfNeeded() -> Int {
        guard isArmed else { return openCount }
        isArmed = false
        openCount += 1
        defaults.set(openCount, forKey: Self.openCountKey)
        return openCount
    }

    /// Re-arms the counter so the next `.active` transition counts as a new open.
    func sceneDidEnterBackground() {
        isArmed = true
    }
}
