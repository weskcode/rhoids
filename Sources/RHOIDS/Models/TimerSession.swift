import SwiftData
import Foundation

@Model
final class TimerSession {
    #Index<TimerSession>([\.startedAt])

    var id: UUID
    var startedAt: Date
    var plannedDuration: TimeInterval
    var endedAt: Date?
    var wasInterrupted: Bool
    var presetName: String?

    init(id: UUID = UUID(), startedAt: Date = Date(), plannedDuration: TimeInterval, endedAt: Date? = nil, wasInterrupted: Bool = false, presetName: String? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.plannedDuration = plannedDuration
        self.endedAt = endedAt
        self.wasInterrupted = wasInterrupted
        self.presetName = presetName
    }

    /// Actual elapsed time from start to end, clamped to
    /// `0...plannedDuration`. A timer can never run longer than planned,
    /// so an `endedAt` past the planned end (e.g. a stale timer whose
    /// completion was recorded days late) is a recording artifact, not
    /// real elapsed time. Falls back to planned duration when `endedAt`
    /// isn't recorded.
    var actualDuration: TimeInterval {
        guard let endedAt else { return plannedDuration }
        return min(max(endedAt.timeIntervalSince(startedAt), 0), plannedDuration)
    }
}
