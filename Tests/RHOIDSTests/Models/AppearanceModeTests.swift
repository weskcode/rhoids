import Testing
import SwiftUI
@testable import RHOIDS

struct AppearanceModeTests {
    @Test func `All modes have unique display names`() {
        let names = AppearanceMode.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test func `All modes use rawValue as ID`() {
        for mode in AppearanceMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
    }

    @Test func `System mode returns nil colorScheme`() {
        #expect(AppearanceMode.system.colorScheme == nil,
                ".system should return nil to defer to the system setting")
    }

    @Test func `Light mode returns light colorScheme`() {
        #expect(AppearanceMode.light.colorScheme == .light)
    }

    @Test func `Dark mode returns dark colorScheme`() {
        #expect(AppearanceMode.dark.colorScheme == .dark)
    }

    @Test func `Expected case count`() {
        #expect(AppearanceMode.allCases.count == 3)
    }
}
