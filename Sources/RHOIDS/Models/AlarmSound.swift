import Foundation
import UserNotifications

/// Catalog of sounds the user can pick from for the timer alarm
/// and the optional 30‑second pre‑alarm warning.
///
/// System cases use Apple's built‑in sounds (no bundle bloat). Bundled
/// cases reference `.caf` files in the app's main bundle (≤ 30 s,
/// Linear PCM / MA4 / µ‑Law / a‑Law per Apple's docs).
///
/// To add a new bundled tone:
///   1. Drop `mytone.caf` into `Sources/RHOIDS/Resources/Sounds/`.
///   2. Add a case with `.bundled("mytone.caf")`.
///   3. Verify with `afinfo mytone.caf` that duration < 30 s and the
///      codec is one of the supported types.
///   4. Run `xcodegen` to regenerate the project (project.yml bundles
///      the Sounds folder as resources).
enum AlarmSound: String, CaseIterable, Identifiable, Codable, Sendable {
    // System sounds (always available, no extra files)
    case systemDefault    // UNNotificationSound.default
    case systemRingtone   // UNNotificationSound.defaultRingtone (iOS 15.2+)

    // ── Original bundled tones ──
    case bell
    case chime
    case marimba
    case digital
    case bubbles

    // ── New bundled tones ──
    case singingBowl
    case gong
    case harp
    case musicBox
    case crystal
    case zen
    case birdsong

    var id: String { rawValue }

    // MARK: - Display

    /// Human‑readable name shown in the picker.
    var displayName: String {
        switch self {
        case .systemDefault:  String(localized: "Default")
        case .systemRingtone: String(localized: "Ringtone")
        case .bell:           String(localized: "Bell")
        case .chime:          String(localized: "Chime")
        case .marimba:        String(localized: "Marimba")
        case .digital:        String(localized: "Digital")
        case .bubbles:        String(localized: "Bubbles")
        case .singingBowl:    String(localized: "Singing Bowl")
        case .gong:           String(localized: "Gong")
        case .harp:           String(localized: "Harp")
        case .musicBox:       String(localized: "Music Box")
        case .crystal:        String(localized: "Crystal")
        case .zen:            String(localized: "Zen")
        case .birdsong:       String(localized: "Birdsong")
        }
    }

    /// Short subtitle shown under the display name in the picker.
    var subtitle: String {
        switch self {
        case .systemDefault:  String(localized: "iOS system alert")
        case .systemRingtone: String(localized: "iOS system ringtone")
        case .bell:           String(localized: "Warm resonant bell strike")
        case .chime:          String(localized: "Gentle wind chime cascade")
        case .marimba:        String(localized: "Mellow wooden mallet")
        case .digital:        String(localized: "Soft electronic rise")
        case .bubbles:        String(localized: "Playful water drops")
        case .singingBowl:    String(localized: "Tibetan bowl with shimmer")
        case .gong:           String(localized: "Deep spacious gong wash")
        case .harp:           String(localized: "Ascending harp arpeggio")
        case .musicBox:       String(localized: "Delicate music-box melody")
        case .crystal:        String(localized: "Shimmering glass bells")
        case .zen:            String(localized: "Quiet woodblock knock")
        case .birdsong:       String(localized: "Soft morning chirps")
        }
    }

    /// SF Symbol used to decorate the picker rows.
    var symbol: String {
        switch self {
        case .systemDefault:  "speaker.wave.2.fill"
        case .systemRingtone: "bell.fill"
        case .bell:           "bell.and.waveform.fill"
        case .chime:          "wind"
        case .marimba:        "music.quarternote.3"
        case .digital:        "waveform"
        case .bubbles:        "drop.fill"
        case .singingBowl:    "circle.and.line.horizontal.fill"
        case .gong:           "circle.fill"
        case .harp:           "music.note"
        case .musicBox:       "music.note.list"
        case .crystal:        "sparkles"
        case .zen:            "leaf.fill"
        case .birdsong:       "bird.fill"
        }
    }

    /// Category for grouping in the picker.
    var category: SoundCategory {
        switch self {
        case .systemDefault, .systemRingtone:   .system
        case .bell, .chime, .marimba, .digital, .bubbles:  .classic
        case .singingBowl, .gong:               .meditative
        case .harp, .musicBox, .crystal:        .melodic
        case .zen, .birdsong:                   .nature
        }
    }

    // MARK: - File mapping

    /// The bundled file name (or nil for system sounds).
    var bundledFileName: String? {
        switch self {
        case .systemDefault, .systemRingtone: nil
        case .bell:         "bell.caf"
        case .chime:        "chime.caf"
        case .marimba:      "marimba.caf"
        case .digital:      "digital.caf"
        case .bubbles:      "bubbles.caf"
        case .singingBowl:  "singing_bowl.caf"
        case .gong:         "gong.caf"
        case .harp:         "harp.caf"
        case .musicBox:     "music_box.caf"
        case .crystal:      "crystal.caf"
        case .zen:          "zen.caf"
        case .birdsong:     "birdsong.caf"
        }
    }

    // MARK: - Notification integration

    /// Resolved `UNNotificationSound`. Falls back to `.default` if the
    /// bundled file is missing - never silently produces no sound.
    func notificationSound() -> UNNotificationSound {
        switch self {
        case .systemDefault:
            return .default
        case .systemRingtone:
            if #available(iOS 15.2, *) { return .defaultRingtone }
            return .default
        default:
            guard let name = bundledFileName,
                  Bundle.main.url(forResource: name, withExtension: nil) != nil
            else { return .default }
            return UNNotificationSound(named: UNNotificationSoundName(name))
        }
    }
}

// MARK: - Sound Category

enum SoundCategory: String, CaseIterable, Identifiable {
    case system
    case classic
    case meditative
    case melodic
    case nature

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:      String(localized: "System")
        case .classic:     String(localized: "Classic")
        case .meditative:  String(localized: "Meditative")
        case .melodic:     String(localized: "Melodic")
        case .nature:      String(localized: "Nature")
        }
    }
}
