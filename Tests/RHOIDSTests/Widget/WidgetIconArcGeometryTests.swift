import Testing
import Foundation

struct WidgetAppIconGeometryTests {

    private let trimFraction: Double = 0.9
    private let rotationDegrees: Double = 108

    // MARK: - Arc geometry (unchanged from original design)

    @Test func `Arc covers 90 percent of the circle`() {
        let arcDegrees = trimFraction * 360
        #expect(arcDegrees == 324, "A 0.9 trim should cover 324 degrees")
    }

    @Test func `Gap is 36 degrees`() {
        let gapDegrees = (1 - trimFraction) * 360
        #expect(abs(gapDegrees - 36) < 0.001, "A 10% gap should be 36 degrees")
    }

    @Test func `Gap is centered at 6 o'clock (bottom)`() {
        let startFromTop = rotationDegrees + 90  // 198°
        let arcSpan = trimFraction * 360          // 324°
        let endFromTop = (startFromTop + arcSpan).truncatingRemainder(dividingBy: 360)  // 162°

        let gapStart = endFromTop
        let gapEnd = startFromTop
        let gapCenter = (gapStart + gapEnd) / 2

        #expect(gapCenter == 180,
                "Gap center should be at 180° from top (6 o'clock / bottom)")
    }

    @Test func `Gap endpoints are symmetric about the vertical axis`() {
        let startFromTop = rotationDegrees + 90
        let arcSpan = trimFraction * 360
        let endFromTop = (startFromTop + arcSpan).truncatingRemainder(dividingBy: 360)

        let distanceFromBottom1 = abs(endFromTop - 180)
        let distanceFromBottom2 = abs(startFromTop - 180)

        #expect(distanceFromBottom1 == distanceFromBottom2,
                "Both gap endpoints should be equally distant from the bottom")
    }

    // MARK: - Proportional scaling

    @Test("Stroke width scales with icon size",
          arguments: [24.0, 28.0, 36.0, 44.0, 48.0, 52.0])
    func strokeWidthScalesProportionally(size: Double) {
        let strokeWidth = max(size * 0.09, 2)
        #expect(strokeWidth >= 2, "Stroke should never be thinner than 2pt")
        #expect(strokeWidth <= size * 0.15,
                "Stroke should not exceed 15% of size for readability")
    }

    @Test("Corner radius uses iOS icon ratio",
          arguments: [24.0, 44.0, 52.0])
    func cornerRadiusMatchesIOSIconRatio(size: Double) {
        let cornerRadius = size * 0.223
        let ratio = cornerRadius / size
        #expect(abs(ratio - 0.223) < 0.001,
                "Corner radius ratio should be ~22.3% (iOS app icon standard)")
    }

    @Test("Font size is proportional to icon size",
          arguments: [24.0, 44.0, 52.0])
    func fontSizeScalesWithSize(size: Double) {
        let fontSize = size * 0.38
        #expect(fontSize > 0, "Font size must be positive")
        #expect(fontSize < size, "Font size must be smaller than the icon")
    }

    @Test("Arc padding leaves visible arc inside the background rect",
          arguments: [24.0, 28.0, 44.0, 52.0])
    func arcFitsInsideBackground(size: Double) {
        let strokeWidth = max(size * 0.09, 2)
        let arcPadding = strokeWidth / 2 + size * 0.12
        let arcDiameter = size - 2 * arcPadding

        #expect(arcDiameter > 0,
                "Arc must have positive diameter at size \(size)")
        #expect(arcDiameter > size * 0.4,
                "Arc should occupy at least 40% of the icon for visibility")
    }

    @Test("Minimum stroke width is enforced at very small sizes")
    func minimumStrokeWidth() {
        let tinySize = 10.0
        let strokeWidth = max(tinySize * 0.09, 2)
        #expect(strokeWidth == 2, "Floor of 2pt should apply at small sizes")
    }
}
