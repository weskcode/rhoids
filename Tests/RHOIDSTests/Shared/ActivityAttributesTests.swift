import Testing
import Foundation
@testable import RHOIDS

struct ActivityAttributesTests {
    @Test func `Attributes store plannedDuration and presetIcon`() {
        let attrs = RHOIDSActivityAttributes(plannedDuration: 180, presetIcon: "checkmark.seal")
        #expect(attrs.plannedDuration == 180)
        #expect(attrs.presetIcon == "checkmark.seal")
    }

    @Test func `ContentState stores endDate and presetName`() {
        let endDate = Date().addingTimeInterval(180)
        let state = RHOIDSActivityAttributes.ContentState(endDate: endDate, presetName: "Recommended")
        #expect(state.endDate == endDate)
        #expect(state.presetName == "Recommended")
    }

    @Test func `ContentState conforms to Codable`() throws {
        let endDate = Date().addingTimeInterval(180)
        let original = RHOIDSActivityAttributes.ContentState(endDate: endDate, presetName: "Max")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RHOIDSActivityAttributes.ContentState.self, from: data)
        #expect(abs(decoded.endDate.timeIntervalSince(original.endDate)) < 0.01)
        #expect(decoded.presetName == original.presetName)
    }

    @Test func `ContentState conforms to Hashable`() {
        let endDate = Date()
        let s1 = RHOIDSActivityAttributes.ContentState(endDate: endDate, presetName: "A")
        let s2 = RHOIDSActivityAttributes.ContentState(endDate: endDate, presetName: "A")
        let s3 = RHOIDSActivityAttributes.ContentState(endDate: endDate, presetName: "B")
        #expect(s1 == s2, "Same values should be equal")
        #expect(s1 != s3, "Different presetName should not be equal")
    }
}
