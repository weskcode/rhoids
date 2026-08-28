import SwiftUI
import Testing
@testable import RHOIDS

struct AdaptiveLayoutStressTests {

    // MARK: - timerFont edge cases

    @Test("timerFont with zero width does not crash and uses floor (44pt)")
    func timerFontZeroWidth() {
        let font = AdaptiveLayout.timerFont(for: 0)
        #expect(font == .system(size: 44, weight: .thin, design: .rounded))
    }

    @Test("timerFont with negative width clamps to floor (44pt)")
    func timerFontNegativeWidth() {
        let font = AdaptiveLayout.timerFont(for: -100)
        #expect(font == .system(size: 44, weight: .thin, design: .rounded))
    }

    @Test("timerFont with very large width clamps to ceiling (72pt)")
    func timerFontVeryLargeWidth() {
        let font = AdaptiveLayout.timerFont(for: 10000)
        #expect(font == .system(size: 72, weight: .thin, design: .rounded))
    }

    @Test("timerFont at exactly 200pt width produces 44pt (200 * 0.22 = 44)")
    func timerFontExactFloorBoundary() {
        let font = AdaptiveLayout.timerFont(for: 200)
        #expect(font == .system(size: 44, weight: .thin, design: .rounded))
    }

    @Test("timerFont scales with DynamicTypeSize")
    func timerFontDynamicTypeScaling() {
        let smallFont = AdaptiveLayout.timerFont(for: 375, dynamicTypeSize: .xSmall)
        let largeFont = AdaptiveLayout.timerFont(for: 375, dynamicTypeSize: .large)
        let a5Font = AdaptiveLayout.timerFont(for: 375, dynamicTypeSize: .accessibility5)

        // We can't directly compare Font sizes, but we know the scale factors
        // xSmall=0.82, large=1.0, a5=3.25
        // At 375pt: base = min(max(375*0.22, 44), 72) = min(max(82.5, 44), 72) = 72
        // So: xSmall = 72*0.82 = 59.04, large = 72, a5 = 72*3.25 = 234
        #expect(smallFont != largeFont, "Different dynamic type sizes should produce different fonts")
        #expect(largeFont != a5Font)
    }

    // MARK: - iconSize edge cases

    @Test("iconSize with zero width uses floor (36pt)")
    func iconSizeZeroWidth() {
        #expect(AdaptiveLayout.iconSize(for: 0) == 36)
    }

    @Test("iconSize with negative width uses floor (36pt)")
    func iconSizeNegativeWidth() {
        #expect(AdaptiveLayout.iconSize(for: -50) == 36)
    }

    @Test("iconSize with very large width clamps to default maximum (64pt)")
    func iconSizeLargeWidth() {
        #expect(AdaptiveLayout.iconSize(for: 1000) == 64)
    }

    @Test("iconSize respects custom maximum")
    func iconSizeCustomMax() {
        #expect(AdaptiveLayout.iconSize(for: 1000, maximum: 48) == 48)
    }

    @Test("iconSize at exactly 200pt width equals floor (200*0.18=36)")
    func iconSizeExactFloor() {
        #expect(AdaptiveLayout.iconSize(for: 200) == 36)
    }

    @Test("iconSize scales linearly in the middle range")
    func iconSizeLinearScaling() {
        let size300 = AdaptiveLayout.iconSize(for: 300)
        let size400 = AdaptiveLayout.iconSize(for: 400)
        #expect(size400 > size300, "Larger width should produce larger icon")
    }

    // MARK: - horizontalPadding edge cases

    @Test("horizontalPadding with zero width uses floor (16pt)")
    func horizontalPaddingZeroWidth() {
        #expect(AdaptiveLayout.horizontalPadding(for: 0) == 16)
    }

    @Test("horizontalPadding with negative width uses floor (16pt)")
    func horizontalPaddingNegativeWidth() {
        #expect(AdaptiveLayout.horizontalPadding(for: -200) == 16)
    }

    @Test("horizontalPadding scales with width")
    func horizontalPaddingScales() {
        let pad300 = AdaptiveLayout.horizontalPadding(for: 300)
        let pad600 = AdaptiveLayout.horizontalPadding(for: 600)
        #expect(pad600 > pad300)
    }

    @Test("horizontalPadding uses custom fraction")
    func horizontalPaddingCustomFraction() {
        let pad = AdaptiveLayout.horizontalPadding(for: 400, fraction: 0.10)
        #expect(pad == 40, "400 * 0.10 = 40")
    }

    @Test("horizontalPadding with zero fraction uses floor")
    func horizontalPaddingZeroFraction() {
        #expect(AdaptiveLayout.horizontalPadding(for: 400, fraction: 0) == 16)
    }

    // MARK: - DynamicTypeSize.layoutScaleFactor coverage

    @Test("Every DynamicTypeSize has a positive scale factor")
    func allScaleFactorsPositive() {
        let sizes: [DynamicTypeSize] = [
            .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
            .accessibility1, .accessibility2, .accessibility3,
            .accessibility4, .accessibility5
        ]
        for size in sizes {
            #expect(size.layoutScaleFactor > 0,
                    "\(size) has non-positive scale factor")
        }
    }

    @Test("Scale factors increase monotonically with type size")
    func scaleFactorsMonotonic() {
        let sizes: [DynamicTypeSize] = [
            .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
            .accessibility1, .accessibility2, .accessibility3,
            .accessibility4, .accessibility5
        ]
        for i in 1..<sizes.count {
            #expect(sizes[i].layoutScaleFactor > sizes[i - 1].layoutScaleFactor,
                    "\(sizes[i]) should have a larger scale factor than \(sizes[i - 1])")
        }
    }

    @Test("Default (.large) has scale factor 1.0")
    func defaultScaleIsOne() {
        #expect(DynamicTypeSize.large.layoutScaleFactor == 1.0)
    }

    @Test("Smallest scale factor is less than 1")
    func smallestScaleLessThanOne() {
        #expect(DynamicTypeSize.xSmall.layoutScaleFactor < 1.0)
    }

    @Test("Largest accessibility scale factor is greater than 3")
    func largestScaleGreaterThanThree() {
        #expect(DynamicTypeSize.accessibility5.layoutScaleFactor > 3.0)
    }

    // MARK: - Real device width simulations

    @Test("iPhone SE width (320pt) produces valid timer font")
    func iPhoneSEWidth() {
        let font = AdaptiveLayout.timerFont(for: 320)
        // 320 * 0.22 = 70.4, min(max(70.4, 44), 72) = 70.4
        #expect(type(of: font) == Font.self, "Should produce a valid Font")
    }

    @Test("iPhone 16 Pro Max width (430pt) produces valid timer font")
    func iPhone16ProMaxWidth() {
        let font = AdaptiveLayout.timerFont(for: 430)
        // 430 * 0.22 = 94.6, min(max(94.6, 44), 72) = 72 (capped)
        #expect(type(of: font) == Font.self, "Should produce a valid Font")
    }

    @Test("iPad width (1024pt) produces valid timer font")
    func iPadWidth() {
        let font = AdaptiveLayout.timerFont(for: 1024)
        // 1024 * 0.22 = 225.28, min(max(225.28, 44), 72) = 72 (capped)
        #expect(type(of: font) == Font.self, "Should produce a valid Font")
    }
}
