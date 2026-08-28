import Foundation
import FamilyControls

/// Typed accessor for the Focus Lock preferences persisted in the shared
/// App Group `UserDefaults`.
///
/// Storage is injectable: production code uses ``shared`` (backed by the App
/// Group suite, preserving the original global behavior), while tests can
/// construct an instance over an isolated suite so concurrent test suites
/// never race on the shared `focusLockEnabled` key.
///
/// `@unchecked Sendable` is sound here: the only stored property is an
/// immutable `let defaults`, and `UserDefaults` is documented as thread-safe,
/// so instances carry no unsynchronized mutable state.
struct FocusLockPreferences: @unchecked Sendable {

    // MARK: - Keys

    static let enabledKey = "focusLockEnabled"
    static let selectionKey = "focusLockSelection"
    static let cooldownDurationKey = "focusLockCooldown"
    static let cooldownEndDateKey = "focusLockCooldownEndDate"
    static let bathroomSessionShouldShieldKey = "focusLockBathroomSessionShouldShield"
    static let shieldsActiveKey = "focusLockShieldsActive"
    static let modeKey = "focusLockMode"

    // MARK: - Defaults

    static let defaultCooldownDuration: TimeInterval = 300

    /// Shared instance backed by the App Group suite. Production call sites use
    /// this; it preserves the original global enum's behavior.
    static let shared = FocusLockPreferences()

    // MARK: - Storage

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: SharedStateKeys.suiteName)) {
        self.defaults = defaults
    }

    /// Convenience for tests that need an isolated, per-test suite.
    init(suiteName: String) {
        self.init(defaults: UserDefaults(suiteName: suiteName))
    }

    // MARK: - Accessors

    var isEnabled: Bool {
        get { defaults?.bool(forKey: Self.enabledKey) ?? false }
        nonmutating set { defaults?.set(newValue, forKey: Self.enabledKey) }
    }

    var cooldownDuration: TimeInterval {
        get {
            let stored = defaults?.double(forKey: Self.cooldownDurationKey) ?? 0
            return stored > 0 ? stored : Self.defaultCooldownDuration
        }
        nonmutating set { defaults?.set(newValue, forKey: Self.cooldownDurationKey) }
    }

    var shieldsActive: Bool {
        get { defaults?.bool(forKey: Self.shieldsActiveKey) ?? false }
        nonmutating set { defaults?.set(newValue, forKey: Self.shieldsActiveKey) }
    }

    var cooldownEndDate: Date? {
        get { defaults?.object(forKey: Self.cooldownEndDateKey) as? Date }
        nonmutating set {
            if let newValue {
                defaults?.set(newValue, forKey: Self.cooldownEndDateKey)
            } else {
                defaults?.removeObject(forKey: Self.cooldownEndDateKey)
            }
        }
    }

    var bathroomSessionShouldShield: Bool {
        get { defaults?.bool(forKey: Self.bathroomSessionShouldShieldKey) ?? false }
        nonmutating set { defaults?.set(newValue, forKey: Self.bathroomSessionShouldShieldKey) }
    }

    /// Which bathroom-focus path the user picked. Defaults to `.phoneFree` -     /// the option that requires no Screen Time authorization - so an
    /// unset/pre-onboarding value never implies app blocking.
    var mode: FocusLockMode {
        get {
            guard let raw = defaults?.string(forKey: Self.modeKey),
                  let mode = FocusLockMode(rawValue: raw) else {
                return .phoneFree
            }
            return mode
        }
        nonmutating set { defaults?.set(newValue.rawValue, forKey: Self.modeKey) }
    }

    var selection: FamilyActivitySelection? {
        get {
            guard let data = defaults?.data(forKey: Self.selectionKey) else { return nil }
            return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        }
        nonmutating set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults?.set(data, forKey: Self.selectionKey)
            } else {
                defaults?.removeObject(forKey: Self.selectionKey)
            }
        }
    }
}
