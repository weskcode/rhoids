import SwiftUI
import Testing
@testable import RHOIDS

/// Covers the `AppToast` model. Identity is intentionally per-instance so that
/// re-presenting the *same* message produces a *different* value - which is
/// what drives `.animation(value:)` to re-run the toast entrance.
struct AppToastTests {
    @Test("Default toast uses the success icon and brand tint")
    func defaults() {
        let toast = AppToast(message: "Saved")
        #expect(toast.message == "Saved")
        #expect(toast.systemImage == "checkmark.circle.fill")
        #expect(toast.tint == .brand)
    }

    @Test("Custom icon and tint are preserved")
    func customValues() {
        let toast = AppToast(message: "Focus Lock turned off", systemImage: "lock.open", tint: .red)
        #expect(toast.systemImage == "lock.open")
        #expect(toast.tint == .red)
    }

    @Test("Two toasts with the same message are not equal (unique identity re-triggers presentation)")
    func uniqueIdentity() {
        let first = AppToast(message: "Same message")
        let second = AppToast(message: "Same message")
        #expect(first.id != second.id)
        #expect(first != second, "Equality is by id, so re-showing the same message animates again")
    }

    @Test("A toast is equal to itself")
    func reflexiveEquality() {
        let toast = AppToast(message: "Hello")
        #expect(toast == toast)
    }
}
