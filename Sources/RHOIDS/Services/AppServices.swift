import Foundation
import UIKit
import WatchConnectivity
import os.log

private let log = Logger(subsystem: "com.wesley.RHOIDS", category: "AppServices")

@MainActor
final class AppServices {
    private(set) static var shared: AppServices?

    let timerService: TimerService
    let notificationService: NotificationService
    let liveActivityService: LiveActivityService
    let sharedStateService: SharedStateService
    let alarmPlayer: AlarmPlayer
    let alarmKitService: AlarmKitService
    let phoneConnectivityService: PhoneConnectivityService
    let screenTimeService: ScreenTimeService
    let tipJarService: TipJarService
    let notificationPermissionService: NotificationPermissionService
    let appOpenTracker: AppOpenTracker
    let dailyUseTracker: DailyUseTracker
    let reviewPromptService: ReviewPromptService

    private var watchConnectivityObserver: Task<Void, Never>?
    private var alarmStopObserver: Task<Void, Never>?

    init() {
        log.debug("initializing all services")
        self.notificationService = NotificationService()
        self.liveActivityService = LiveActivityService()
        self.sharedStateService = SharedStateService()
        self.alarmPlayer = AlarmPlayer()
        self.alarmKitService = AlarmKitService()
        self.phoneConnectivityService = PhoneConnectivityService()
        self.screenTimeService = ScreenTimeService()
        self.timerService = TimerService(
            notificationService: notificationService,
            liveActivityService: liveActivityService,
            sharedStateService: sharedStateService,
            alarmPlayer: alarmPlayer,
            alarmKitService: alarmKitService,
            screenTimeSessionScheduling: screenTimeService
        )
        self.tipJarService = TipJarService()
        self.notificationPermissionService = NotificationPermissionService()
        self.appOpenTracker = AppOpenTracker()
        self.dailyUseTracker = DailyUseTracker()
        self.reviewPromptService = ReviewPromptService()
        AppServices.shared = self
        log.debug("all services ready")

        setupWatchConnectivity()
        observeExternalAlarmStops()
    }

    /// Watch for the system alarm being stopped/dismissed from outside the
    /// app (most importantly the Dynamic Island Stop button). When that
    /// happens and the app isn't in the foreground, the in-app completion
    /// flow never runs, so we reconcile here: tear down the orphaned Live
    /// Activity, looping audio, and pending notifications. When the app *is*
    /// active, the in-app flow (completion sheet / `tryRecoverCompletion`)
    /// owns teardown, so we skip to avoid cancelling an alarm the user is
    /// actively looking at.
    private func observeExternalAlarmStops() {
        alarmStopObserver = Task { [weak self] in
            guard let self else { return }
            for await _ in self.alarmKitService.stoppedAlarms() {
                guard UIApplication.shared.applicationState != .active else { continue }
                await self.timerService.handleExternalAlarmStop()
            }
        }
    }

    /// Wire up Watch connectivity to forward timer events and respond to state requests.
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }

        // Forward iPhone timer events to Watch. TimerService finishes all
        // event streams after a terminal event (.completed / .cancelled), so
        // re-subscribe in a loop - otherwise the Watch would stop hearing
        // about every timer after the first one.
        watchConnectivityObserver = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                for await event in await self.timerService.eventStream() {
                    switch event {
                    case .started(let endDate, let preset, let duration):
                        self.phoneConnectivityService.send(.timerStarted(
                            endDate: endDate,
                            presetName: preset.name,
                            duration: duration
                        ))
                    case .completed(let preset, let duration):
                        self.phoneConnectivityService.send(.timerCompleted(
                            presetName: preset?.name ?? "Unknown",
                            duration: duration
                        ))
                    case .cancelled:
                        self.phoneConnectivityService.send(.timerCancelled)
                    case .tick:
                        break // Don't spam the Watch with every tick
                    }
                }
                // Stream ended after a terminal event - loop to re-subscribe
                // for the next timer run.
            }
        }

        phoneConnectivityService.onWatchTimerEvent = { [weak self] message in
            guard let self else { return }
            switch message {
            case .timerStarted(let endDate, let presetName, let duration):
                // Watch started a timer - adopt it with the Watch's own
                // endDate so both devices finish at the same instant. A
                // fallback preset preserves the carried name (e.g. localized
                // mismatches) instead of mislabeling the timer "Recommended".
                let preset = PresetTimer.all.first { $0.name == presetName }
                    ?? PresetTimer(
                        id: UUID(),
                        name: presetName,
                        duration: duration,
                        subtitle: "",
                        systemImage: "timer",
                        isRecommended: false
                    )
                log.debug("Watch started timer - adopting: \(presetName), ends \(endDate)")
                Task {
                    await self.timerService.adopt(endDate: endDate, preset: preset, duration: duration)
                }

            case .timerCancelled:
                log.debug("Watch cancelled timer")
                Task { await self.timerService.stop() }

            case .requestState:
                // Watch is asking for current timer state
                Task {
                    let state = await self.timerService.timerState()
                    self.phoneConnectivityService.sendStateResponse(
                        endDate: state.endDate,
                        isRunning: state.isRunning,
                        presetName: state.preset?.name,
                        duration: state.duration
                    )
                }

            default:
                break
            }
        }
    }
}

#if DEBUG
extension AppServices {
    static let preview = AppServices()
}
#endif
