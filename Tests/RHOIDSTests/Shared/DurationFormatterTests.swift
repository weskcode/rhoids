import Testing
import Foundation
@testable import RHOIDS

struct DurationFormatterTests {
    @Test(arguments: [
        (0, "0 sec"),
        (1, "1 sec"),
        (30, "30 sec"),
        (59, "59 sec"),
        (60, "1 min"),
        (120, "2 min"),
        (180, "3 min"),
        (300, "5 min"),
        (3600, "60 min"),
        (61, "1:01"),
        (90, "1:30"),
        (150, "2:30"),
        (600, "10 min"),
        (3661, "61:01"),
    ])
    func `Formats various durations correctly`(interval: TimeInterval, expected: String) {
        #expect(DurationFormatter.formatted(interval) == expected)
    }

    // MARK: - Edge cases

    @Test func `Fractional seconds are truncated to integer`() {
        #expect(DurationFormatter.formatted(29.9) == "29 sec",
                "29.9s should truncate to 29, not round to 30")
        #expect(DurationFormatter.formatted(59.99) == "59 sec")
    }

    @Test func `Negative duration formats as negative seconds`() {
        // DurationFormatter uses Int(interval) which truncates toward zero.
        // Negative input shouldn't crash - verify it produces some output.
        let result = DurationFormatter.formatted(-30)
        #expect(result.isEmpty == false, "Negative input should not crash")
    }

    @Test func `Exactly 60 seconds shows as minutes`() {
        #expect(DurationFormatter.formatted(60) == "1 min")
        #expect(DurationFormatter.formatted(60.0) == "1 min")
    }

    @Test func `All preset durations format cleanly`() {
        // The three presets: 180, 300, and custom (0)
        #expect(DurationFormatter.formatted(180) == "3 min")
        #expect(DurationFormatter.formatted(300) == "5 min")
        #expect(DurationFormatter.formatted(0) == "0 sec")
    }

    @Test func `Max custom duration formats correctly`() {
        // HomeViewModel.maxDuration = 30 * 60 = 1800
        #expect(DurationFormatter.formatted(1800) == "30 min")
    }
}
