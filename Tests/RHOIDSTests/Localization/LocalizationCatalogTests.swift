import Foundation
import Testing
@testable import RHOIDS

/// Validates `Sources/Localizable.xcstrings` directly as data, independent of any
/// particular view. Catches the two failure modes localization work regresses on
/// silently: a new string shipped without translations, and a translation whose
/// format placeholders no longer match its English source (which crashes or mis-renders
/// at the call site rather than failing to build).
struct LocalizationCatalogTests {
    private enum TestError: Error {
        case projectRootNotFound
        case catalogUnreadable
    }

    private static let requiredLocales = [
        "ar", "de", "es", "fr", "hi", "it", "ja", "ko", "pt-BR", "ru", "tr", "zh-Hans",
    ]

    /// Keys intentionally exempt from full-locale translation: pure format/punctuation
    /// placeholders, the app's own brand name, and academic citation titles that stay in
    /// their originally published language. Growing this list should be a deliberate,
    /// reviewed decision, not a silent side effect of forgetting to translate a new string.
    private static let exemptKeys: Set<String> = [
        "%@", "%@ · %@", "%@ min", "%@, %@", "%@%%", "0:00", "R", "RHOIDS", "RHOIDS · %@",
        "%@. %@", "%@, %@, %@",
        "Esmaeilnia Shirvani et al., Annals of Medicine, 2025",
        "Hemorrhoids: from basic pathophysiology to clinical management",
        "Lohsiriwat, World J. Gastroenterology, 2012",
        "Ramprasad et al., PLOS One, 2025",
        "Smartphone use on the toilet and the risk of hemorrhoids",
        "Worldwide prevalence of haemorrhoids",
    ]

    private func findProjectRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<10 {
            dir = dir.deletingLastPathComponent()
            let pbxproj = dir.appendingPathComponent("RHOIDS.xcodeproj/project.pbxproj")
            if FileManager.default.fileExists(atPath: pbxproj.path) {
                return dir
            }
        }
        throw TestError.projectRootNotFound
    }

    private func loadCatalog() throws -> [String: [String: Any]] {
        let root = try findProjectRoot()
        let catalogURL = root.appendingPathComponent("Sources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: [String: Any]] else {
            throw TestError.catalogUnreadable
        }
        return strings
    }

    private func localizedValue(_ entry: [String: Any], locale: String) -> String? {
        guard let localizations = entry["localizations"] as? [String: Any],
              let localization = localizations[locale] as? [String: Any],
              let stringUnit = localization["stringUnit"] as? [String: Any],
              let value = stringUnit["value"] as? String else {
            return nil
        }
        return value
    }

    @Test func `Every non-exempt key has a non-empty Spanish translation`() throws {
        let strings = try loadCatalog()
        let missing = strings.keys
            .filter { !Self.exemptKeys.contains($0) }
            .filter { key in
                guard let value = localizedValue(strings[key] ?? [:], locale: "es") else { return true }
                return value.isEmpty
            }
            .sorted()
        #expect(missing.isEmpty, "Keys missing a Spanish translation: \(missing)")
    }

    @Test func `Every non-exempt key has all 12 supported locales`() throws {
        let strings = try loadCatalog()
        var incomplete: [String: [String]] = [:]
        for (key, entry) in strings where !Self.exemptKeys.contains(key) {
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            let missingLocales = Self.requiredLocales.filter { !localizations.keys.contains($0) }
            if !missingLocales.isEmpty {
                incomplete[key] = missingLocales
            }
        }
        #expect(incomplete.isEmpty, "Keys missing locales: \(incomplete)")
    }

    @Test func `No translated value across any locale is empty`() throws {
        let strings = try loadCatalog()
        var emptyValues: [String] = []
        for (key, entry) in strings {
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            for locale in localizations.keys {
                if let value = localizedValue(entry, locale: locale), value.isEmpty {
                    emptyValues.append("\(key) [\(locale)]")
                }
            }
        }
        #expect(emptyValues.isEmpty, "Empty translated values: \(emptyValues.sorted())")
    }

    @Test func `Spanish translations preserve the source key's format placeholder count`() throws {
        let strings = try loadCatalog()
        var mismatches: [String] = []
        for (key, entry) in strings {
            let expectedCount = key.components(separatedBy: "%@").count - 1
            guard expectedCount > 0 else { continue }
            guard let value = localizedValue(entry, locale: "es") else { continue }
            let actualCount = value.components(separatedBy: "%@").count - 1
            if actualCount != expectedCount {
                mismatches.append("\(key) -> es has \(actualCount) placeholder(s), expected \(expectedCount)")
            }
        }
        #expect(mismatches.isEmpty, "Placeholder mismatches: \(mismatches)")
    }

    @Test("Every supported locale preserves the source key's format placeholder count",
          arguments: requiredLocales)
    func placeholdersPreservedAcrossAllLocales(locale: String) throws {
        let strings = try loadCatalog()
        var mismatches: [String] = []
        for (key, entry) in strings {
            let expectedCount = key.components(separatedBy: "%@").count - 1
            guard expectedCount > 0 else { continue }
            guard let value = localizedValue(entry, locale: locale) else { continue }
            let actualCount = value.components(separatedBy: "%@").count - 1
            if actualCount != expectedCount {
                mismatches.append("\(key) -> \(actualCount) placeholder(s), expected \(expectedCount)")
            }
        }
        #expect(mismatches.isEmpty, "[\(locale)] placeholder mismatches: \(mismatches)")
    }

    @Test func `Spanish locale is declared in project knownRegions`() throws {
        let root = try findProjectRoot()
        let projectYML = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        guard let line = projectYML.split(separator: "\n").first(where: { $0.contains("knownRegions") }) else {
            Issue.record("knownRegions not found in project.yml")
            return
        }
        #expect(line.contains("es"), "Spanish (es) must be listed in project.yml knownRegions")
    }
}
