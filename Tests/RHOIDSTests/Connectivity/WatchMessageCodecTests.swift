import Foundation
import Testing
@testable import RHOIDS

struct WatchMessageCodecTests {

    // MARK: - Round-trip encoding/decoding

    @Test("timerStarted survives dictionary round-trip")
    func timerStartedRoundTrip() throws {
        let endDate = Date(timeIntervalSince1970: 1_700_000_000)
        let msg = WatchMessage.timerStarted(endDate: endDate, presetName: "Recommended", duration: 180)
        let dict = msg.toDictionary()
        let decoded = try #require(WatchMessage.from(dictionary: dict))

        guard case .timerStarted(let d, let name, let dur, let runID, let sentAt) = decoded else {
            Issue.record("Expected .timerStarted"); return
        }
        #expect(abs(d.timeIntervalSince(endDate)) < 0.01)
        #expect(name == "Recommended")
        #expect(dur == 180)
        #expect(runID == nil)
        #expect(sentAt == nil)
    }

    @Test("timerCompleted survives dictionary round-trip")
    func timerCompletedRoundTrip() throws {
        let msg = WatchMessage.timerCompleted(presetName: "Max", duration: 300)
        let dict = msg.toDictionary()
        let decoded = try #require(WatchMessage.from(dictionary: dict))

        guard case .timerCompleted(let name, let dur, let runID, let sentAt) = decoded else {
            Issue.record("Expected .timerCompleted"); return
        }
        #expect(name == "Max")
        #expect(dur == 300)
        #expect(runID == nil)
        #expect(sentAt == nil)
    }

    @Test("timerCancelled survives dictionary round-trip")
    func timerCancelledRoundTrip() throws {
        let msg = WatchMessage.timerCancelled()
        let decoded = try #require(WatchMessage.from(dictionary: msg.toDictionary()))
        guard case .timerCancelled(let runID, let sentAt) = decoded else {
            Issue.record("Expected .timerCancelled"); return
        }
        #expect(runID == nil)
        #expect(sentAt == nil)
    }

    @Test("requestState survives dictionary round-trip")
    func requestStateRoundTrip() throws {
        let msg = WatchMessage.requestState
        let decoded = try #require(WatchMessage.from(dictionary: msg.toDictionary()))
        guard case .requestState = decoded else {
            Issue.record("Expected .requestState"); return
        }
    }

    @Test("stateResponse with nil endDate survives round-trip")
    func stateResponseNilEndDate() throws {
        let msg = WatchMessage.stateResponse(endDate: nil, isRunning: false, presetName: nil, duration: 0)
        let decoded = try #require(WatchMessage.from(dictionary: msg.toDictionary()))
        guard case .stateResponse(let ed, let running, let name, let dur, _, _) = decoded else {
            Issue.record("Expected .stateResponse"); return
        }
        #expect(ed == nil)
        #expect(running == false)
        #expect(name == nil)
        #expect(dur == 0)
    }

    @Test("stateResponse with all fields populated survives round-trip")
    func stateResponseFullPayload() throws {
        let endDate = Date().addingTimeInterval(120)
        let runID = UUID()
        let sentAt = Date(timeIntervalSince1970: 1_700_000_050)
        let msg = WatchMessage.stateResponse(
            endDate: endDate,
            isRunning: true,
            presetName: "Custom",
            duration: 240,
            runID: runID,
            sentAt: sentAt
        )
        let decoded = try #require(WatchMessage.from(dictionary: msg.toDictionary()))
        guard case .stateResponse(let ed, let running, let name, let dur, let decodedRunID, let decodedSentAt) = decoded else {
            Issue.record("Expected .stateResponse"); return
        }
        #expect(ed != nil)
        #expect(running == true)
        #expect(name == "Custom")
        #expect(dur == 240)
        #expect(decodedRunID == runID)
        let unwrappedSentAt = try #require(decodedSentAt)
        #expect(abs(unwrappedSentAt.timeIntervalSince(sentAt)) < 0.01)
    }

    @Test("runID and sentAt survive round-trip on lifecycle messages")
    func syncMetadataRoundTrip() throws {
        let runID = UUID()
        let sentAt = Date(timeIntervalSince1970: 1_700_000_123)
        let endDate = Date(timeIntervalSince1970: 1_700_000_303)

        let started = try #require(WatchMessage.from(dictionary: WatchMessage.timerStarted(
            endDate: endDate,
            presetName: "Recommended",
            duration: 180,
            runID: runID,
            sentAt: sentAt
        ).toDictionary()))
        guard case .timerStarted(_, _, _, let sRunID, let sSentAt) = started else {
            Issue.record("Expected .timerStarted"); return
        }
        #expect(sRunID == runID)
        #expect(abs((try #require(sSentAt)).timeIntervalSince(sentAt)) < 0.01)

        let completed = try #require(WatchMessage.from(dictionary: WatchMessage.timerCompleted(
            presetName: "Max",
            duration: 300,
            runID: runID,
            sentAt: sentAt
        ).toDictionary()))
        guard case .timerCompleted(_, _, let cRunID, let cSentAt) = completed else {
            Issue.record("Expected .timerCompleted"); return
        }
        #expect(cRunID == runID)
        #expect(abs((try #require(cSentAt)).timeIntervalSince(sentAt)) < 0.01)

        let cancelled = try #require(WatchMessage.from(dictionary: WatchMessage.timerCancelled(
            runID: runID,
            sentAt: sentAt
        ).toDictionary()))
        guard case .timerCancelled(let xRunID, let xSentAt) = cancelled else {
            Issue.record("Expected .timerCancelled"); return
        }
        #expect(xRunID == runID)
        #expect(abs((try #require(xSentAt)).timeIntervalSince(sentAt)) < 0.01)
    }

    @Test("Legacy payloads without runID or sentAt decode with nil metadata")
    func legacyPayloadsDecode() throws {
        let legacyCancel: [String: Any] = ["watchMessage": ["type": "timerCancelled"]]
        let decodedCancel = try #require(WatchMessage.from(dictionary: legacyCancel))
        guard case .timerCancelled(let runID, let sentAt) = decodedCancel else {
            Issue.record("Expected .timerCancelled"); return
        }
        #expect(runID == nil)
        #expect(sentAt == nil)

        let legacyState: [String: Any] = [
            "watchMessage": [
                "type": "stateResponse",
                "isRunning": false,
                "duration": 0
            ]
        ]
        let decodedState = try #require(WatchMessage.from(dictionary: legacyState))
        guard case .stateResponse(let endDate, let isRunning, let presetName, let duration, let stateRunID, let stateSentAt) = decodedState else {
            Issue.record("Expected .stateResponse"); return
        }
        #expect(endDate == nil)
        #expect(isRunning == false)
        #expect(presetName == nil)
        #expect(duration == 0)
        #expect(stateRunID == nil)
        #expect(stateSentAt == nil)
    }

    @Test("timerTick with zero remaining survives round-trip")
    func timerTickZero() throws {
        let msg = WatchMessage.timerTick(remaining: 0)
        let decoded = try #require(WatchMessage.from(dictionary: msg.toDictionary()))
        guard case .timerTick(let rem) = decoded else {
            Issue.record("Expected .timerTick"); return
        }
        #expect(rem == 0)
    }

    @Test("timerTick with fractional remaining survives round-trip")
    func timerTickFractional() throws {
        let msg = WatchMessage.timerTick(remaining: 42.756)
        let decoded = try #require(WatchMessage.from(dictionary: msg.toDictionary()))
        guard case .timerTick(let rem) = decoded else {
            Issue.record("Expected .timerTick"); return
        }
        #expect(abs(rem - 42.756) < 0.001)
    }

    // MARK: - Corrupt / malformed dictionary handling

    @Test("from(dictionary:) returns nil for empty dictionary")
    func emptyDictionaryReturnsNil() {
        #expect(WatchMessage.from(dictionary: [:]) == nil)
    }

    @Test("from(dictionary:) returns nil when watchMessage key is missing")
    func missingWatchMessageKey() {
        let dict: [String: Any] = ["somethingElse": ["type": "timerStarted"]]
        #expect(WatchMessage.from(dictionary: dict) == nil)
    }

    @Test("from(dictionary:) returns nil for garbage payload")
    func garbagePayload() {
        // watchMessage must be a dictionary, not an array or primitive
        let dict: [String: Any] = ["watchMessage": [1, 2, 3]]
        #expect(WatchMessage.from(dictionary: dict) == nil)
    }

    @Test("from(dictionary:) returns nil for unknown message type")
    func unknownMessageType() {
        let dict: [String: Any] = ["watchMessage": ["type": "unknownFutureMessage"]]
        #expect(WatchMessage.from(dictionary: dict) == nil)
    }

    @Test("from(dictionary:) returns nil when required fields are missing")
    func missingRequiredFields() {
        let dict: [String: Any] = ["watchMessage": ["type": "timerStarted"]]
        #expect(WatchMessage.from(dictionary: dict) == nil,
                "timerStarted without endDate/presetName/duration should fail")
    }

    @Test("from(dictionary:) returns nil for type mismatch in payload")
    func typeMismatchInPayload() {
        let dict: [String: Any] = [
            "watchMessage": [
                "type": "timerTick",
                "remaining": "not a number"
            ]
        ]
        #expect(WatchMessage.from(dictionary: dict) == nil)
    }

    // MARK: - JSON Codable round-trip (direct encoder/decoder, not dictionary)

    @Test("All message types survive direct JSON Codable round-trip")
    func allMessageTypesJSONRoundTrip() throws {
        let messages: [WatchMessage] = [
            .timerStarted(endDate: Date(), presetName: "Recommended", duration: 180),
            .timerTick(remaining: 90),
            .timerCompleted(presetName: "Max", duration: 300),
            .timerCancelled(),
            .requestState,
            .stateResponse(endDate: Date(), isRunning: true, presetName: "Custom", duration: 120),
            .stateResponse(endDate: nil, isRunning: false, presetName: nil, duration: 0)
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for original in messages {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(WatchMessage.self, from: data)

            switch (original, decoded) {
            case (.timerStarted(_, let n1, let d1, let r1, _), .timerStarted(_, let n2, let d2, let r2, _)):
                #expect(n1 == n2); #expect(d1 == d2); #expect(r1 == r2)
            case (.timerTick(let r1), .timerTick(let r2)):
                #expect(abs(r1 - r2) < 0.001)
            case (.timerCompleted(let n1, let d1, let r1, _), .timerCompleted(let n2, let d2, let r2, _)):
                #expect(n1 == n2); #expect(d1 == d2); #expect(r1 == r2)
            case (.timerCancelled(let r1, _), .timerCancelled(let r2, _)):
                #expect(r1 == r2)
            case (.requestState, .requestState): break
            case (.stateResponse(_, let run1, _, let d1, let r1, _), .stateResponse(_, let run2, _, let d2, let r2, _)):
                #expect(run1 == run2); #expect(d1 == d2); #expect(r1 == r2)
            default:
                Issue.record("Type mismatch: original and decoded don't match")
            }
        }
    }

    // MARK: - toDictionary edge case

    @Test("toDictionary produces non-empty result for all message types")
    func toDictionaryNeverEmpty() {
        let messages: [WatchMessage] = [
            .timerStarted(endDate: Date(), presetName: "", duration: 0),
            .timerTick(remaining: 0),
            .timerCompleted(presetName: "", duration: 0),
            .timerCancelled(),
            .requestState,
            .stateResponse(endDate: nil, isRunning: false, presetName: nil, duration: 0)
        ]

        for msg in messages {
            let dict = msg.toDictionary()
            #expect(dict.isEmpty == false, "toDictionary() should never return empty for valid messages")
            #expect(dict["watchMessage"] != nil, "Must contain the 'watchMessage' wrapper key")
        }
    }
}
