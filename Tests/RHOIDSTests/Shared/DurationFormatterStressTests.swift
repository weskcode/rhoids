import Foundation
import Testing
@testable import RHOIDS

struct DurationFormatterStressTests {

    // MARK: - Extreme values

    @Test("Very large duration does not crash or produce empty string")
    func veryLargeDuration() {
        let result = DurationFormatter.formatted(999_999)
        #expect(result.isEmpty == false, "Should produce some output for huge values")
        #expect(result.contains("min") || result.contains(":"),
                "Large values should format as minutes")
    }

    @Test("Very large minute value does not crash")
    func veryLargeMinuteValue() {
        // Test with a huge but Int-safe duration (1 year in seconds)
        let result = DurationFormatter.formatted(31_536_000)
        #expect(result.isEmpty == false, "Should handle year-scale durations")
    }

    @Test("Negative duration does not crash")
    func negativeDuration() {
        let result = DurationFormatter.formatted(-1)
        #expect(result.isEmpty == false)
    }

    @Test("Large negative duration does not crash")
    func largeNegativeDuration() {
        let result = DurationFormatter.formatted(-86400)
        #expect(result.isEmpty == false)
    }

    @Test("Sub-second positive value formats as 0 sec")
    func subSecondValue() {
        #expect(DurationFormatter.formatted(0.5) == "0 sec",
                "0.5s truncates to 0")
        #expect(DurationFormatter.formatted(0.999) == "0 sec")
    }

    // MARK: - Boundary values around 60 seconds

    @Test("59.99 seconds formats as seconds, not minutes")
    func justUnderOneMinute() {
        #expect(DurationFormatter.formatted(59.99) == "59 sec")
    }

    @Test("60.01 seconds formats with mixed notation")
    func justOverOneMinute() {
        let result = DurationFormatter.formatted(60.01)
        #expect(result == "1 min", "60.01 truncates to 60 total seconds = 1 min exact")
    }

    @Test("119 seconds formats as 1:59")
    func twoMinutesBoundary() {
        #expect(DurationFormatter.formatted(119) == "1:59")
    }

    @Test("121 seconds formats as 2:01")
    func justOverTwoMinutes() {
        #expect(DurationFormatter.formatted(121) == "2:01")
    }

    // MARK: - All preset durations

    @Test("Every PresetTimer.all duration formats without crash")
    func allPresetDurationsFormat() {
        for preset in PresetTimer.all {
            let result = DurationFormatter.formatted(preset.duration)
            #expect(result.isEmpty == false, "Preset '\(preset.name)' (duration=\(preset.duration)) should format")
        }
    }

    // MARK: - Custom duration range sweep

    @Test("Every minute from 1 to 30 formats as 'N min'")
    func minuteRangeSweep() {
        for minutes in 1...30 {
            let seconds = TimeInterval(minutes * 60)
            let result = DurationFormatter.formatted(seconds)
            #expect(result == "\(minutes) min",
                    "Expected '\(minutes) min' but got '\(result)'")
        }
    }

    @Test("Every second from 0 to 59 formats as 'N sec'")
    func secondRangeSweep() {
        for sec in 0...59 {
            let result = DurationFormatter.formatted(TimeInterval(sec))
            #expect(result == "\(sec) sec",
                    "Expected '\(sec) sec' but got '\(result)'")
        }
    }

    // MARK: - Formatting consistency

    @Test("Seconds portion always has leading zero in mixed format")
    func leadingZeroInMixedFormat() {
        for sec in 1...9 {
            let interval = TimeInterval(60 + sec)
            let result = DurationFormatter.formatted(interval)
            #expect(result == "1:0\(sec)",
                    "Expected '1:0\(sec)' but got '\(result)' - seconds should be zero-padded")
        }
    }

    @Test("10+ seconds in mixed format have no extra padding")
    func noPaddingOverTen() {
        let result = DurationFormatter.formatted(70)
        #expect(result == "1:10")
        let result2 = DurationFormatter.formatted(119)
        #expect(result2 == "1:59")
    }
}
