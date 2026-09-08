import Testing
import Foundation
@testable import RHOIDS

/// Proves `DurationFormatter.formatted(_:bundle:locale:)` actually pulls a
/// translated string out of `Localizable.xcstrings`, rather than silently
/// falling back to the untranslated interpolated key. `DurationFormatterTests`
/// and `DurationFormatterStressTests` only ever run in the process's ambient
/// (English) locale, so they pass identically whether localization is wired
/// up correctly or completely broken - this file targets specific
/// non-English `.lproj` bundles and checks the result against the exact
/// translations recorded in the catalog (rhoids-change-control G3).
///
/// `RHOIDSTests` is a *hosted* unit test bundle - `project.pbxproj` sets
/// `TEST_HOST = $(BUILT_PRODUCTS_DIR)/RHOIDS.app/RHOIDS` for it - so at test
/// run time `Bundle.main` is the RHOIDS app bundle, not the RHOIDSTests
/// bundle. `AlarmSoundTests.swift` already relies on exactly this to look up
/// bundled `.caf` files via `Bundle.main.url(forResource:...)`.
/// `Localizable.xcstrings` is declared as a `buildPhase: resources` resource
/// of the `RHOIDS` app target in `project.yml`, so Xcode compiles it into a
/// `Localizable.strings` file under each locale's `<locale>.lproj` directory
/// inside `RHOIDS.app`, same as any other localized resource. Opening one of
/// those `.lproj` directories directly as its own `Bundle` forces that
/// translation regardless of the test runner's system language.
struct DurationFormatterLocalizationTests {
    private func localizedBundle(for identifier: String) throws -> Bundle {
        let path = try #require(
            Bundle.main.path(forResource: identifier, ofType: "lproj"),
            "\(identifier).lproj not found in the host app bundle - either RHOIDSTests isn't " +
            "hosted by RHOIDS.app anymore, or Localizable.xcstrings stopped compiling " +
            "per-locale .strings resources into it"
        )
        return try #require(Bundle(path: path), "Could not open \(identifier).lproj as a Bundle")
    }

    @Test func `German locale produces the catalog's whole-minute translation`() throws {
        let bundle = try localizedBundle(for: "de")
        let result = DurationFormatter.formatted(180, bundle: bundle, locale: Locale(identifier: "de"))
        #expect(result == "3 Min.",
                "Expected the German '%lld Min.' translation from Localizable.xcstrings, got '\(result)'")
    }

    @Test func `German locale produces the catalog's sub-minute translation`() throws {
        let bundle = try localizedBundle(for: "de")
        let result = DurationFormatter.formatted(45, bundle: bundle, locale: Locale(identifier: "de"))
        #expect(result == "45 Sek.",
                "Expected the German '%lld Sek.' translation from Localizable.xcstrings, got '\(result)'")
    }

    @Test func `Arabic locale produces the catalog's whole-minute translation`() throws {
        let bundle = try localizedBundle(for: "ar")
        let result = DurationFormatter.formatted(180, bundle: bundle, locale: Locale(identifier: "ar"))
        #expect(result.contains("دقيقة"),
                "Expected the Arabic '%lld دقيقة' translation from Localizable.xcstrings, got '\(result)'")
        #expect(result != "3 min", "Should not have fallen back to the untranslated English key")
    }

    @Test func `Arabic locale produces the catalog's sub-minute translation`() throws {
        let bundle = try localizedBundle(for: "ar")
        let result = DurationFormatter.formatted(45, bundle: bundle, locale: Locale(identifier: "ar"))
        #expect(result.contains("ثانية"),
                "Expected the Arabic '%lld ثانية' translation from Localizable.xcstrings, got '\(result)'")
        #expect(result != "45 sec", "Should not have fallen back to the untranslated English key")
    }

    @Test func `Mixed minute-second format is digits-only regardless of bundle or locale`() throws {
        // DurationFormatter.swift documents this format ("M:SS") as
        // deliberately untranslated so the running countdown keeps a stable,
        // compact shape everywhere - it should be unaffected by bundle/locale.
        let bundle = try localizedBundle(for: "de")
        let result = DurationFormatter.formatted(90, bundle: bundle, locale: Locale(identifier: "de"))
        #expect(result == "1:30")
    }

    @Test func `Default bundle and locale parameters preserve existing call sites`() {
        // No bundle/locale passed - exercises the (.main, .current) defaults
        // every pre-existing call site relies on continuing to compile and
        // behave unchanged.
        #expect(DurationFormatter.formatted(180) == "3 min")
        #expect(DurationFormatter.formatted(45) == "45 sec")
    }
}
