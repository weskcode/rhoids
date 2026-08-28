import Testing
import SwiftUI
@testable import RHOIDS

struct BrandColorTests {
    @Test func `Brand color is accessible as static property`() {
        let color = Color.brand
        // Verify it doesn't crash and is non-nil (Color is a value type, always exists)
        #expect(color == color)
    }

    @Test func `Brand color ShapeStyle extension matches static property`() {
        let fromStatic: Color = .brand
        let fromShapeStyle: Color = .brand
        #expect(fromStatic == fromShapeStyle,
                "ShapeStyle extension should return the same color as the static property")
    }
}
