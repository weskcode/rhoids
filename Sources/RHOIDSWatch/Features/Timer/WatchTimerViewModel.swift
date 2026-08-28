import Foundation
import SwiftUI

/// ViewModel for the Watch timer running screen.
///
/// Observes `WatchTimerService` events and drives the ring + countdown UI.
@Observable
@MainActor
final class WatchTimerViewModel {
    var elapsed: TimeInterval = 0
    var endDate: Date = Date()
    var plannedDuration: TimeInterval = 0
    var presetName: String = ""
    var presetIcon: String = ""
    var isComplete = false
    var isCancelled = false
    var completionQuip: String = ""

    private let timerService: WatchTimerService

    @ObservationIgnored
    private var observerTask: Task<Void, Never>?

    init(timerService: WatchTimerService) {
        self.timerService = timerService
        observerTask = Task { [weak self] in
            await self?.observeTimer()
        }
    }

    isolated deinit {
        observerTask?.cancel()
    }

    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        return min(max(elapsed / plannedDuration, 0), 1)
    }

    var remainingProgress: Double {
        1 - progress
    }

    var safeEndDate: Date {
        max(endDate, Date())
    }

    func stopTimer() {
        Task { await timerService.stop() }
    }

    /// Cancel the background observer task. Used by tests to isolate
    /// computed-property tests from async event stream activity.
    func cancelObserver() {
        observerTask?.cancel()
        observerTask = nil
    }

    private func observeTimer() async {
        // Sync current state if timer is already running
        await syncCurrentState()

        for await event in await timerService.eventStream() {
            switch event {
            case .started(let date, let preset, let duration):
                endDate = date
                plannedDuration = duration
                presetName = preset.name
                presetIcon = preset.systemImage
                elapsed = 0
                isComplete = false
                isCancelled = false

            case .tick(let remainingTime):
                elapsed = max(plannedDuration - remainingTime, 0)

            case .completed(_, _):
                isComplete = true
                completionQuip = TimerQuip.randomCompletion().body

            case .cancelled:
                isCancelled = true
                completionQuip = TimerQuip.randomEarlyStop().body
            }
        }
    }

    private func syncCurrentState() async {
        let currentEnd = await timerService.currentEndDate
        let currentPreset = await timerService.currentPreset
        let currentDuration = await timerService.currentDuration

        if let currentEnd, let currentPreset, currentDuration > 0 {
            endDate = currentEnd
            plannedDuration = currentDuration
            presetName = currentPreset.name
            presetIcon = currentPreset.systemImage
            elapsed = max(currentDuration - currentEnd.timeIntervalSinceNow, 0)
        }
    }
}
