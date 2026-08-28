import Foundation
import Testing
@testable import RHOIDS

@MainActor
@Suite(.serialized)
struct TimerViewModelCompletionTests {

    // MARK: - completionDismissed

    @Test("completionDismissed sets shouldDismiss to true")
    func completionDismissedSetsDismiss() async {
        let vm = makeViewModel()
        #expect(vm.shouldDismiss == false)
        vm.completionDismissed()
        await waitUntil { vm.shouldDismiss }
        #expect(vm.shouldDismiss == true)
    }

    @Test("completionDismissed is safe to call multiple times")
    func completionDismissedIdempotent() async {
        let vm = makeViewModel()
        vm.completionDismissed()
        vm.completionDismissed()
        await waitUntil { vm.shouldDismiss }
        #expect(vm.shouldDismiss == true)
    }

    @Test("Natural completion prepares an eligible native review request after dismissal")
    func naturalCompletionPreparesReviewAfterDismissal() async {
        let suiteName = "com.test.rhoids.tvm-review-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let reviewService = ReviewPromptService(defaults: defaults)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        reviewService.recordSuccessfulTimer(at: yesterday)
        reviewService.recordSuccessfulTimer(at: yesterday.addingTimeInterval(60))

        let sharedState = SharedStateService(suiteName: suiteName)
        let timerService = makeTimerService(sharedStateService: sharedState)
        let focusPreferences = FocusLockPreferences(suiteName: suiteName)
        focusPreferences.isEnabled = false
        let vm = TimerViewModel(
            timerService: timerService,
            alarmPlayer: AlarmPlayer(),
            sharedStateService: sharedState,
            liveActivityService: LiveActivityService(),
            alarmKitService: AlarmKitService(),
            screenTimeService: ScreenTimeService(),
            focusLockPreferences: focusPreferences,
            reviewPromptService: reviewService
        )

        vm.startObserving()
        try? await Task.sleep(for: .milliseconds(100))
        await timerService.start(
            duration: 0.1,
            preset: .recommended,
            preferences: quietPreferences()
        )
        await waitUntil { vm.outcome != nil }

        #expect(reviewService.completedTimerCount == 3)
        #expect(reviewService.activeDayCount == 2)
        #expect(reviewService.shouldRequestReview == false,
                "The request must wait until the completion UI is dismissed")

        vm.completionDismissed()
        await waitUntil { vm.shouldDismiss }
        vm.stopObserving()

        #expect(reviewService.consumeReviewRequest())
        #expect(reviewService.consumeReviewRequest() == false,
                "The prepared StoreKit opportunity must be consumed once")
    }

    // MARK: - Observer lifecycle

    @Test("startObserving is idempotent - calling twice does not crash or double-observe")
    func startObservingIdempotent() {
        let vm = makeViewModel()
        vm.startObserving()
        vm.startObserving()
        vm.stopObserving()
    }

    @Test("stopObserving without startObserving is safe")
    func stopObservingWithoutStart() {
        let vm = makeViewModel()
        vm.stopObserving()
    }

    @Test("startObserving then stopObserving is a clean lifecycle")
    func observerLifecycle() {
        let vm = makeViewModel()
        vm.startObserving()
        vm.stopObserving()
        #expect(vm.outcome == nil, "No events should have produced an outcome")
    }

    // MARK: - stopTimer interaction with outcome

    @Test("stopTimer before any outcome leaves outcome nil (event comes async)")
    func stopTimerLeavesOutcomeNil() {
        let vm = makeViewModel()
        vm.plannedDuration = 180
        vm.startDate = Date().addingTimeInterval(-60)
        vm.endDate = Date().addingTimeInterval(120)
        vm.stopTimer()
        #expect(vm.outcome == nil,
                "The .cancelled event and outcome assignment happen via the async stream")
    }

    // MARK: - Frozen countdown edge cases

    @Test("stopTimer at the very start freezes near zero elapsed")
    func stopTimerAtStart() {
        let vm = makeViewModel()
        vm.plannedDuration = 180
        vm.startDate = Date()
        vm.endDate = Date().addingTimeInterval(180)
        vm.stopTimer()
        #expect(vm.isCountdownFrozen == true)
        #expect(vm.elapsed >= 0)
        #expect(vm.elapsed < 5, "Elapsed should be near zero when stopped immediately")
    }

    @Test("stopTimer near the end freezes near planned duration")
    func stopTimerNearEnd() {
        let vm = makeViewModel()
        vm.plannedDuration = 180
        vm.startDate = Date().addingTimeInterval(-175)
        vm.endDate = Date().addingTimeInterval(5)
        vm.stopTimer()
        #expect(vm.isCountdownFrozen == true)
        if let remaining = vm.frozenRemaining {
            #expect(remaining >= 0)
            #expect(remaining <= 10)
        }
    }

    @Test("frozenRemaining is never negative after stop")
    func frozenRemainingNeverNegative() {
        let vm = makeViewModel()
        vm.plannedDuration = 60
        vm.startDate = Date().addingTimeInterval(-120)
        vm.endDate = Date().addingTimeInterval(-60)
        vm.stopTimer()
        if let remaining = vm.frozenRemaining {
            #expect(remaining >= 0, "Frozen remaining must never be negative")
        }
    }

    // MARK: - setModelContext

    @Test("setModelContext does not crash with nil initially")
    func setModelContextNilStart() {
        let vm = makeViewModel()
        #expect(vm.outcome == nil)
    }

    // MARK: - Helpers

    private func makeViewModel() -> TimerViewModel {
        let suiteName = "com.test.rhoids.tvmcomp-\(UUID().uuidString)"
        let sharedState = SharedStateService(suiteName: suiteName)
        return TimerViewModel(
            timerService: makeTimerService(sharedStateService: sharedState),
            alarmPlayer: AlarmPlayer(),
            sharedStateService: sharedState,
            liveActivityService: LiveActivityService(),
            alarmKitService: AlarmKitService(),
            screenTimeService: ScreenTimeService(),
            focusLockPreferences: FocusLockPreferences(suiteName: suiteName),
            reviewPromptService: ReviewPromptService(defaults: UserDefaults(suiteName: suiteName)!)
        )
    }

    private func makeTimerService(sharedStateService: SharedStateService) -> TimerService {
        TimerService(
            notificationService: NotificationService(),
            liveActivityService: LiveActivityService(),
            sharedStateService: sharedStateService,
            alarmPlayer: AlarmPlayer(),
            alarmKitService: AlarmKitService(),
            screenTimeSessionScheduling: NoOpScreenTimeSessionScheduling(),
            sideEffectsEnabled: false
        )
    }

    private func quietPreferences() -> TimerService.TimerPreferences {
        TimerService.TimerPreferences(
            notificationsEnabled: false,
            warningEnabled: false,
            warningMode: .endOnly,
            hapticsEnabled: false,
            alarmSound: .systemDefault,
            warningSound: .systemDefault
        )
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
