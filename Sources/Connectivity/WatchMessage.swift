import Foundation

/// Real-time messages sent between iPhone and Apple Watch for timer state sync.
///
/// Sent via `WCSession.sendMessage(_:replyHandler:errorHandler:)` for
/// immediate delivery when both devices are reachable, or queued via
/// `transferUserInfo(_:)` when the counterpart is unreachable.
enum WatchMessage: Codable, Sendable {
    case timerStarted(endDate: Date, presetName: String, duration: TimeInterval)
    case timerTick(remaining: TimeInterval)
    case timerCompleted(presetName: String, duration: TimeInterval)
    case timerCancelled
    case requestState
    case stateResponse(endDate: Date?, isRunning: Bool, presetName: String?, duration: TimeInterval)

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case type, endDate, presetName, duration, remaining, isRunning
    }

    private enum MessageType: String, Codable {
        case timerStarted, timerTick, timerCompleted, timerCancelled
        case requestState, stateResponse
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .timerStarted(let endDate, let presetName, let duration):
            try container.encode(MessageType.timerStarted, forKey: .type)
            try container.encode(endDate, forKey: .endDate)
            try container.encode(presetName, forKey: .presetName)
            try container.encode(duration, forKey: .duration)
        case .timerTick(let remaining):
            try container.encode(MessageType.timerTick, forKey: .type)
            try container.encode(remaining, forKey: .remaining)
        case .timerCompleted(let presetName, let duration):
            try container.encode(MessageType.timerCompleted, forKey: .type)
            try container.encode(presetName, forKey: .presetName)
            try container.encode(duration, forKey: .duration)
        case .timerCancelled:
            try container.encode(MessageType.timerCancelled, forKey: .type)
        case .requestState:
            try container.encode(MessageType.requestState, forKey: .type)
        case .stateResponse(let endDate, let isRunning, let presetName, let duration):
            try container.encode(MessageType.stateResponse, forKey: .type)
            try container.encodeIfPresent(endDate, forKey: .endDate)
            try container.encode(isRunning, forKey: .isRunning)
            try container.encodeIfPresent(presetName, forKey: .presetName)
            try container.encode(duration, forKey: .duration)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        switch type {
        case .timerStarted:
            let endDate = try container.decode(Date.self, forKey: .endDate)
            let presetName = try container.decode(String.self, forKey: .presetName)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .timerStarted(endDate: endDate, presetName: presetName, duration: duration)
        case .timerTick:
            let remaining = try container.decode(TimeInterval.self, forKey: .remaining)
            self = .timerTick(remaining: remaining)
        case .timerCompleted:
            let presetName = try container.decode(String.self, forKey: .presetName)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .timerCompleted(presetName: presetName, duration: duration)
        case .timerCancelled:
            self = .timerCancelled
        case .requestState:
            self = .requestState
        case .stateResponse:
            let endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
            let isRunning = try container.decode(Bool.self, forKey: .isRunning)
            let presetName = try container.decodeIfPresent(String.self, forKey: .presetName)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .stateResponse(endDate: endDate, isRunning: isRunning, presetName: presetName, duration: duration)
        }
    }

    // MARK: - Dictionary Conversion (for WCSession)

    /// Encode to a dictionary suitable for `WCSession.sendMessage`.
    func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return ["watchMessage": dict]
    }

    /// Decode from a WCSession message dictionary.
    static func from(dictionary: [String: Any]) -> WatchMessage? {
        guard let dict = dictionary["watchMessage"],
              let data = try? JSONSerialization.data(withJSONObject: dict)
        else { return nil }
        return try? JSONDecoder().decode(WatchMessage.self, from: data)
    }
}
