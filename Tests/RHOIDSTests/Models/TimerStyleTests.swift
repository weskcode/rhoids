import Testing
import Foundation
@testable import RHOIDS

struct TimerStyleTests {
    @Test func `All styles have unique display names`() {
        let names = TimerStyle.allCases.map(\.displayName)
        #expect(Set(names).count == names.count,
                "Every TimerStyle must have a unique display name")
    }

    @Test func `All styles have non-empty descriptions`() {
        for style in TimerStyle.allCases {
            #expect(style.description.isEmpty == false,
                    "\(style) has an empty description")
        }
    }

    @Test func `All styles use rawValue as ID`() {
        for style in TimerStyle.allCases {
            #expect(style.id == style.rawValue)
        }
    }

    @Test func `Expected case count matches allCases`() {
        #expect(TimerStyle.allCases.count == 6,
                "If a new TimerStyle was added, update this test and add a view for it")
    }

    @Test(arguments: TimerStyle.allCases)
    func `Display names are user-friendly single words`(style: TimerStyle) {
        #expect(style.displayName.count <= 10,
                "\(style) display name '\(style.displayName)' is too long for UI")
    }

    // MARK: - Raw value stability

    /// `timerStyle` is persisted via `@AppStorage("timerStyle")` in four views
    /// and mirrored to the Watch through `SyncedPreferences`. The raw values are
    /// therefore an on-disk format: changing any of them silently resets every
    /// user's saved choice back to `.card`. This test pins them in place.
    @Test func `Raw values are stable and must never change`() {
        let expected: [TimerStyle: String] = [
            .card: "card",
            .ring: "ring",
            .progress: "progress",
            .flip: "flip",
            .dial: "dial",
            .gauge: "gauge",
        ]

        for style in TimerStyle.allCases {
            #expect(expected[style] == style.rawValue,
                    "Raw value for \(style) changed - this breaks persistence and Watch sync")
        }

        #expect(expected.count == TimerStyle.allCases.count,
                "A TimerStyle case is missing from the stability map")
    }

    @Test(arguments: TimerStyle.allCases)
    func `Each style round-trips through its raw value`(style: TimerStyle) {
        #expect(TimerStyle(rawValue: style.rawValue) == style)
    }

    /// Guards against confusing the user-facing `displayName` (e.g. "Bar") with
    /// the persisted `rawValue` (e.g. "progress"), plus casing/typo drift.
    @Test(arguments: ["", "Card", "CARD", "bar", "Bar", "unknown", "progressbar", " card "])
    func `Unknown raw values do not map to a style`(rawValue: String) {
        #expect(TimerStyle(rawValue: rawValue) == nil,
                "'\(rawValue)' must not resolve to a TimerStyle")
    }

    // MARK: - User-facing copy

    /// The whole point of the Timer Display page is letting users tell the
    /// styles apart, so each must carry a distinct description.
    @Test func `All styles have unique descriptions`() {
        let descriptions = TimerStyle.allCases.map(\.description)
        #expect(Set(descriptions).count == descriptions.count,
                "Descriptions must be unique so users can distinguish styles on the picker")
    }

    /// Pins the visible labels, including the deliberate case where `.progress`
    /// shows as "Bar" rather than its raw value.
    @Test func `Display names match their expected labels`() {
        #expect(TimerStyle.card.displayName == "Card")
        #expect(TimerStyle.ring.displayName == "Ring")
        #expect(TimerStyle.progress.displayName == "Bar")
        #expect(TimerStyle.flip.displayName == "Flip")
        #expect(TimerStyle.dial.displayName == "Dial")
        #expect(TimerStyle.gauge.displayName == "Gauge")
    }

    // MARK: - Persistence contract shared by the picker and its readers

    /// Mirrors the full save → load cycle: the picker writes `style.rawValue`
    /// under `timerStyleKey`, and HomeView / TimerRunningView read it back.
    @Test(arguments: TimerStyle.allCases)
    func `Selecting a style persists under the shared storage key`(style: TimerStyle) throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(style.rawValue, forKey: UserPreferences.timerStyleKey)

        let storedRaw = try #require(defaults.string(forKey: UserPreferences.timerStyleKey))
        #expect(TimerStyle(rawValue: storedRaw) == style,
                "\(style) must survive a round-trip through the timerStyle storage key")
    }

    @Test func `Missing stored value falls back to card`() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storedRaw = defaults.string(forKey: UserPreferences.timerStyleKey)
        let resolved = storedRaw.flatMap(TimerStyle.init(rawValue:)) ?? .card
        #expect(resolved == .card,
                "With nothing stored, every @AppStorage(\"timerStyle\") defaults to .card")
    }

    @Test func `Corrupt stored value falls back to card`() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("not-a-real-style", forKey: UserPreferences.timerStyleKey)

        let storedRaw = defaults.string(forKey: UserPreferences.timerStyleKey)
        let resolved = storedRaw.flatMap(TimerStyle.init(rawValue:)) ?? .card
        #expect(resolved == .card,
                "An unreadable stored value must fall back to .card, not crash")
    }
}
