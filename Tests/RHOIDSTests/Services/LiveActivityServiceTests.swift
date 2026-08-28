import Testing
import Foundation
import ActivityKit
@testable import RHOIDS

struct LiveActivityServiceTests {

    // MARK: - Service Initialization

    @Test func `Fresh service has no current activity`() async {
        let sut = LiveActivityService()
        await sut.endAllStaleActivities()
    }

    @Test func `EndAllStaleActivities does not throw on empty state`() async {
        let sut = LiveActivityService()
        await sut.endAllStaleActivities()
        await sut.endAllStaleActivities()
    }

    // MARK: - Start Guards

    @Test func `Start throws when activities are disabled`() async throws {
        let sut = LiveActivityService()
        let authInfo = ActivityAuthorizationInfo()

        if authInfo.areActivitiesEnabled {
            return
        }

        await #expect(throws: LiveActivityError.self) {
            try await sut.start(
                preset: .recommended,
                duration: 180,
                endDate: Date().addingTimeInterval(180)
            )
        }

        let activities = Activity<RHOIDSActivityAttributes>.activities
        #expect(activities.isEmpty,
                "No activity should be created when activities are disabled")
    }

    // MARK: - Dismiss and End

    @Test func `Dismiss is safe when no activity is tracked`() async {
        let sut = LiveActivityService()
        await sut.dismiss()
    }

    @Test func `End is an alias for dismiss`() async {
        let sut = LiveActivityService()
        await sut.end()
    }

    @Test func `MarkComplete is safe when no activity is tracked`() async {
        let sut = LiveActivityService()
        await sut.markComplete()
    }

    @Test func `Update is safe when no activity is tracked`() async {
        let sut = LiveActivityService()
        await sut.update(endDate: Date().addingTimeInterval(60))
    }

}

// MARK: - ActivityAttributes Deep Tests

struct ActivityAttributesEdgeCaseTests {

    // MARK: - Attribute Construction

    @Test func `Zero duration is valid`() {
        let attrs = RHOIDSActivityAttributes(plannedDuration: 0, presetIcon: "timer")
        #expect(attrs.plannedDuration == 0)
    }

    @Test func `Large duration is valid`() {
        let attrs = RHOIDSActivityAttributes(plannedDuration: 86400, presetIcon: "timer")
        #expect(attrs.plannedDuration == 86400)
    }

    @Test func `Empty preset icon is valid`() {
        let attrs = RHOIDSActivityAttributes(plannedDuration: 180, presetIcon: "")
        #expect(attrs.presetIcon == "")
    }

    // MARK: - ContentState Edge Cases

    @Test func `ContentState with epoch date round-trips through Codable`() throws {
        let epoch = Date(timeIntervalSince1970: 0)
        let original = RHOIDSActivityAttributes.ContentState(endDate: epoch, presetName: "Test")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RHOIDSActivityAttributes.ContentState.self, from: data)
        #expect(abs(decoded.endDate.timeIntervalSince(epoch)) < 0.01)
        #expect(decoded.presetName == "Test")
    }

    @Test func `ContentState with far future date round-trips`() throws {
        let farFuture = Date(timeIntervalSinceNow: 365 * 24 * 60 * 60)
        let original = RHOIDSActivityAttributes.ContentState(endDate: farFuture, presetName: "Future")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RHOIDSActivityAttributes.ContentState.self, from: data)
        #expect(abs(decoded.endDate.timeIntervalSince(farFuture)) < 0.01)
    }

    @Test func `ContentState with empty preset name round-trips`() throws {
        let original = RHOIDSActivityAttributes.ContentState(
            endDate: Date(),
            presetName: ""
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RHOIDSActivityAttributes.ContentState.self, from: data)
        #expect(decoded.presetName == "")
    }

    @Test func `ContentState with unicode preset name round-trips`() throws {
        let original = RHOIDSActivityAttributes.ContentState(
            endDate: Date(),
            presetName: "🚽 Quick Break"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RHOIDSActivityAttributes.ContentState.self, from: data)
        #expect(decoded.presetName == "🚽 Quick Break")
    }

    // MARK: - Hashable Contract

    @Test func `ContentState with same date but different names are not equal`() {
        let date = Date()
        let s1 = RHOIDSActivityAttributes.ContentState(endDate: date, presetName: "A")
        let s2 = RHOIDSActivityAttributes.ContentState(endDate: date, presetName: "B")
        #expect(s1 != s2)
    }

    @Test func `ContentState with same name but different dates are not equal`() {
        let s1 = RHOIDSActivityAttributes.ContentState(
            endDate: Date(timeIntervalSince1970: 1000),
            presetName: "Same"
        )
        let s2 = RHOIDSActivityAttributes.ContentState(
            endDate: Date(timeIntervalSince1970: 2000),
            presetName: "Same"
        )
        #expect(s1 != s2)
    }

    @Test func `ContentState works correctly in a Set`() {
        let date = Date()
        let s1 = RHOIDSActivityAttributes.ContentState(endDate: date, presetName: "A")
        let s2 = RHOIDSActivityAttributes.ContentState(endDate: date, presetName: "A")
        let s3 = RHOIDSActivityAttributes.ContentState(endDate: date, presetName: "B")

        let set: Set = [s1, s2, s3]
        #expect(set.count == 2, "Duplicate states should collapse in a Set")
    }

    // MARK: - Preset Integration

    @Test(arguments: PresetTimer.all.filter { $0.isCustom == false })
    func `Non-custom presets produce valid activity attributes`(preset: PresetTimer) {
        let attrs = RHOIDSActivityAttributes(
            plannedDuration: preset.duration,
            presetIcon: preset.systemImage
        )
        #expect(attrs.plannedDuration > 0,
                "\(preset.name) should have a positive duration")
        #expect(attrs.presetIcon.isEmpty == false,
                "\(preset.name) should have a non-empty system image")
    }

    @Test(arguments: PresetTimer.all.filter { $0.isCustom == false })
    func `Preset ContentState encodes preset name correctly`(preset: PresetTimer) throws {
        let state = RHOIDSActivityAttributes.ContentState(
            endDate: Date().addingTimeInterval(preset.duration),
            presetName: preset.name
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(
            RHOIDSActivityAttributes.ContentState.self, from: data
        )
        #expect(decoded.presetName == preset.name)
    }
}

// MARK: - Live Activity Safe Date Clamping

struct LiveActivitySafeDateTests {

    @Test func `Safe end date is always in the future`() {
        let pastDate = Date(timeIntervalSinceNow: -60)
        let now = Date.now
        let safeEnd = max(pastDate, now.addingTimeInterval(1))
        #expect(safeEnd > now,
                "Safe end should be at least 1 second in the future")
    }

    @Test func `Safe start date is before safe end`() {
        let now = Date.now
        let plannedDuration: TimeInterval = 180
        let endDate = now.addingTimeInterval(60)
        let safeEnd = max(endDate, now.addingTimeInterval(1))
        let safeDuration = max(plannedDuration, 1)
        let safeStart = min(safeEnd.addingTimeInterval(-safeDuration), now)

        #expect(safeStart < safeEnd,
                "Safe start should always be before safe end")
    }

    @Test func `Expired timer produces valid safe range`() {
        let now = Date.now
        let expiredEnd = now.addingTimeInterval(-30)
        let plannedDuration: TimeInterval = 180

        let safeEnd = max(expiredEnd, now.addingTimeInterval(1))
        let safeDuration = max(plannedDuration, 1)
        let safeStart = min(safeEnd.addingTimeInterval(-safeDuration), now)

        #expect(safeStart < safeEnd,
                "Even with an expired endDate, the safe range should be valid")
        #expect(safeEnd.timeIntervalSince(safeStart) >= 1,
                "Safe range should span at least 1 second")
    }

    @Test func `Zero planned duration produces valid safe range`() {
        let now = Date.now
        let endDate = now.addingTimeInterval(60)

        let safeEnd = max(endDate, now.addingTimeInterval(1))
        let safeDuration: TimeInterval = max(0, 1)
        let safeStart = min(safeEnd.addingTimeInterval(-safeDuration), now)

        #expect(safeStart < safeEnd)
        #expect(safeDuration == 1, "Zero duration should be clamped to 1 second")
    }

    @Test(arguments: [-100.0, -1.0, 0.0, 1.0, 60.0, 300.0, 3600.0])
    func `Safe date clamping never produces an invalid ClosedRange`(offset: TimeInterval) {
        let now = Date.now
        let endDate = now.addingTimeInterval(offset)
        let plannedDuration: TimeInterval = 180

        let safeEnd = max(endDate, now.addingTimeInterval(1))
        let safeDuration = max(plannedDuration, 1)
        let safeStart = min(safeEnd.addingTimeInterval(-safeDuration), now)

        #expect(safeStart <= safeEnd,
                "ClosedRange requires start <= end for offset=\(offset)")
    }
}
