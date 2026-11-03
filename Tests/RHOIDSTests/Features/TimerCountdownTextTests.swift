import Testing
import Foundation
@testable import RHOIDS

struct TimerCountdownTextTests {
    @Test("Frozen countdown matches the live timer's shape", arguments: [
        (0.0, "0:00"),
        (9.0, "0:09"),
        (159.0, "2:39"),
        (158.2, "2:39"),
        (180.0, "3:00"),
        (599.0, "9:59"),
        (600.0, "10:00"),
        (3723.0, "1:02:03"),
        (-5.0, "0:00"),
    ])
    func formatted(seconds: TimeInterval, expected: String) {
        #expect(TimerCountdownText.formatted(seconds) == expected)
    }
}
