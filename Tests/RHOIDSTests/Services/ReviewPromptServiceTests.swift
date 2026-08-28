import Testing
import Foundation
@testable import RHOIDS

@MainActor
struct ReviewPromptServiceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "com.test.rhoids.review-\(UUID().uuidString)")!
    }

    @Test("Eligibility requires meaningful engagement")
    func eligibilityConstants() {
        #expect(ReviewPromptService.minimumCompletedTimers == 3)
        #expect(ReviewPromptService.minimumActiveDays == 2)
        #expect(ReviewPromptService.requestCooldown == 120 * 24 * 60 * 60)
    }

    @Test("Manual rating actions use the production App Store destinations")
    func appStoreDestinations() {
        #expect(AppStoreInfo.writeReviewURL?.absoluteString ==
                "https://apps.apple.com/app/id6772689484?action=write-review")
        #expect(AppStoreInfo.productURL?.absoluteString ==
                "https://apps.apple.com/app/id6772689484")
    }

    @Test("Fresh service has no pending review request")
    func freshState() {
        let sut = ReviewPromptService(defaults: freshDefaults(), calendar: calendar)
        #expect(sut.completedTimerCount == 0)
        #expect(sut.activeDayCount == 0)
        #expect(sut.shouldRequestReview == false)
        #expect(sut.consumeReviewRequest() == false)
    }

    @Test("Successful timers are counted")
    func completedTimersAreCounted() {
        let sut = ReviewPromptService(defaults: freshDefaults(), calendar: calendar)
        sut.recordSuccessfulTimer(at: Date(timeIntervalSince1970: 1_000_000))
        sut.recordSuccessfulTimer(at: Date(timeIntervalSince1970: 1_000_100))
        #expect(sut.completedTimerCount == 2)
        #expect(sut.activeDayCount == 1)
    }

    @Test("Three timers on one day do not trigger a review")
    func oneDayIsNotEnough() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let sut = ReviewPromptService(defaults: freshDefaults(), calendar: calendar)
        for offset in [0.0, 60.0, 120.0] {
            sut.recordSuccessfulTimer(at: now.addingTimeInterval(offset))
        }

        sut.prepareReviewRequestIfEligible(now: now.addingTimeInterval(180))

        #expect(sut.completedTimerCount == 3)
        #expect(sut.activeDayCount == 1)
        #expect(sut.shouldRequestReview == false)
    }

    @Test("Three timers across two days trigger the native review opportunity")
    func meaningfulEngagementBecomesEligible() {
        let dayOne = Date(timeIntervalSince1970: 1_000_000)
        let dayTwo = dayOne.addingTimeInterval(24 * 60 * 60)
        let sut = ReviewPromptService(defaults: freshDefaults(), calendar: calendar)
        sut.recordSuccessfulTimer(at: dayOne)
        sut.recordSuccessfulTimer(at: dayOne.addingTimeInterval(60))
        sut.recordSuccessfulTimer(at: dayTwo)

        sut.prepareReviewRequestIfEligible(now: dayTwo.addingTimeInterval(60))

        #expect(sut.shouldRequestReview)
        #expect(sut.consumeReviewRequest(at: dayTwo.addingTimeInterval(60)))
        #expect(sut.shouldRequestReview == false)
    }

    @Test("A queued request does not start the cooldown until StoreKit is invoked")
    func queuedRequestDoesNotStartCooldown() {
        let defaults = freshDefaults()
        let dayOne = Date(timeIntervalSince1970: 1_000_000)
        let dayTwo = dayOne.addingTimeInterval(24 * 60 * 60)
        let firstSession = ReviewPromptService(defaults: defaults, calendar: calendar)
        firstSession.recordSuccessfulTimer(at: dayOne)
        firstSession.recordSuccessfulTimer(at: dayOne.addingTimeInterval(60))
        firstSession.recordSuccessfulTimer(at: dayTwo)
        firstSession.prepareReviewRequestIfEligible(now: dayTwo)
        #expect(firstSession.shouldRequestReview)

        let nextSession = ReviewPromptService(defaults: defaults, calendar: calendar)
        nextSession.prepareReviewRequestIfEligible(now: dayTwo.addingTimeInterval(60))

        #expect(nextSession.shouldRequestReview)
    }

    @Test("Review request is prepared at most once per session")
    func oncePerSession() {
        let dayOne = Date(timeIntervalSince1970: 1_000_000)
        let dayTwo = dayOne.addingTimeInterval(24 * 60 * 60)
        let sut = ReviewPromptService(defaults: freshDefaults(), calendar: calendar)
        sut.recordSuccessfulTimer(at: dayOne)
        sut.recordSuccessfulTimer(at: dayOne.addingTimeInterval(60))
        sut.recordSuccessfulTimer(at: dayTwo)
        sut.prepareReviewRequestIfEligible(now: dayTwo)
        #expect(sut.consumeReviewRequest(at: dayTwo))

        sut.prepareReviewRequestIfEligible(now: dayTwo.addingTimeInterval(ReviewPromptService.requestCooldown))

        #expect(sut.shouldRequestReview == false)
    }

    @Test("Cooldown persists across app sessions")
    func cooldownPersists() {
        let defaults = freshDefaults()
        let dayOne = Date(timeIntervalSince1970: 1_000_000)
        let dayTwo = dayOne.addingTimeInterval(24 * 60 * 60)
        let firstSession = ReviewPromptService(defaults: defaults, calendar: calendar)
        firstSession.recordSuccessfulTimer(at: dayOne)
        firstSession.recordSuccessfulTimer(at: dayOne.addingTimeInterval(60))
        firstSession.recordSuccessfulTimer(at: dayTwo)
        firstSession.prepareReviewRequestIfEligible(now: dayTwo)
        #expect(firstSession.consumeReviewRequest(at: dayTwo))

        let beforeCooldown = ReviewPromptService(defaults: defaults, calendar: calendar)
        beforeCooldown.prepareReviewRequestIfEligible(
            now: dayTwo.addingTimeInterval(ReviewPromptService.requestCooldown - 1)
        )
        #expect(beforeCooldown.shouldRequestReview == false)

        let afterCooldown = ReviewPromptService(defaults: defaults, calendar: calendar)
        afterCooldown.prepareReviewRequestIfEligible(
            now: dayTwo.addingTimeInterval(ReviewPromptService.requestCooldown)
        )
        #expect(afterCooldown.shouldRequestReview)
    }
}
