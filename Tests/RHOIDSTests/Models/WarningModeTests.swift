import Testing
import Foundation
@testable import RHOIDS

struct WarningModeTests {
    @Test func `All modes have unique display names`() {
        let names = WarningMode.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test func `All modes use rawValue as ID`() {
        for mode in WarningMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
    }

    @Test func `Expected case count`() {
        #expect(WarningMode.allCases.count == 2)
    }

    @Test func `Settings description is non-empty for all modes`() {
        for mode in WarningMode.allCases {
            #expect(mode.settingsDescription.isEmpty == false,
                    "\(mode.rawValue) must have a settings description")
        }
    }

    @Test(arguments: [
        ("endOnly", WarningMode.endOnly),
        ("recurring", WarningMode.recurring),
    ])
    func `Raw value roundtrips`(rawValue: String, expected: WarningMode) {
        #expect(WarningMode(rawValue: rawValue) == expected)
        #expect(expected.rawValue == rawValue)
    }

    @Test func `Codable roundtrip preserves value`() throws {
        let original = WarningMode.recurring
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WarningMode.self, from: data)
        #expect(decoded == original)
    }

    @Test func `TimerPreferences defaults to endOnly`() {
        let prefs = TimerService.TimerPreferences()
        #expect(prefs.warningMode == .endOnly)
    }
}
