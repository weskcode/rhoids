import Testing
import SwiftUI
@testable import RHOIDS

struct AdaptiveLayoutTests {
    @Test func `Timer font returns a valid font for any width`() {
        let small = AdaptiveLayout.timerFont(for: 320)
        let large = AdaptiveLayout.timerFont(for: 430)
        #expect(small != large)
    }

    @Test func `Timer font respects dynamic type scale`() {
        let font = AdaptiveLayout.timerFont(for: 375, dynamicTypeSize: .xSmall)
        let fontLarge = AdaptiveLayout.timerFont(for: 375, dynamicTypeSize: .accessibility5)
        #expect(font != fontLarge)
    }

    @Test(arguments: [
        (200, CGFloat(36)),
        (375, CGFloat(64)),
        (100, CGFloat(36)),
    ])
    func `Icon size is capped at maximum`(width: CGFloat, expected: CGFloat) {
        let size = AdaptiveLayout.iconSize(for: width)
        #expect(size == expected)
    }

    @Test func `Icon size never exceeds maximum`() {
        let size = AdaptiveLayout.iconSize(for: 1000, maximum: 64)
        #expect(size <= 64)
    }

    @Test(arguments: [
        (320, CGFloat(16)),
        (375, CGFloat(18.75)),
        (430, CGFloat(21.5)),
    ])
    func `Horizontal padding has minimum floor`(width: CGFloat, expected: CGFloat) {
        let padding = AdaptiveLayout.horizontalPadding(for: width)
        #expect(padding == expected)
    }

    @Test func `Horizontal padding never goes below 16`() {
        let tiny = AdaptiveLayout.horizontalPadding(for: 100)
        #expect(tiny >= 16)

        let normal = AdaptiveLayout.horizontalPadding(for: 375)
        #expect(normal >= 16)
    }

    @Test func `DynamicTypeScale increases with larger sizes`() {
        let scales: [(DynamicTypeSize, CGFloat)] = [
            (.xSmall, 0.82),
            (.small, 0.88),
            (.medium, 0.94),
            (.large, 1.0),
            (.xLarge, 1.12),
            (.xxLarge, 1.23),
            (.xxxLarge, 1.35),
            (.accessibility1, 1.60),
            (.accessibility2, 1.90),
            (.accessibility3, 2.25),
            (.accessibility4, 2.75),
            (.accessibility5, 3.25),
        ]
        for (size, expected) in scales {
            #expect(size.layoutScaleFactor == expected)
        }
    }
}
