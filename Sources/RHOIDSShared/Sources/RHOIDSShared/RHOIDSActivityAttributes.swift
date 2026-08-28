import ActivityKit
import Foundation

public struct RHOIDSActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var endDate: Date
        public var presetName: String

        public init(endDate: Date, presetName: String) {
            self.endDate = endDate
            self.presetName = presetName
        }
    }

    public var plannedDuration: TimeInterval
    public var presetIcon: String

    public init(plannedDuration: TimeInterval, presetIcon: String) {
        self.plannedDuration = plannedDuration
        self.presetIcon = presetIcon
    }
}
