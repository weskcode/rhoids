import AppIntents
import Foundation
import WidgetKit

struct StartTimerIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Start RHOIDS Timer"
    static let description = IntentDescription("Start a bathroom timer to prevent hemorrhoids.")

    @Parameter(title: "Preset", optionsProvider: TimerPresetQuery())
    var preset: TimerPresetEntity?

    func perform() async throws -> some IntentResult {
        guard let preset = preset else { return .result() }
        let presetTimer = PresetTimer.all.first { $0.id.uuidString == preset.id }
            ?? PresetTimer.recommended
        let duration = presetTimer.duration > 0 ? presetTimer.duration : preset.duration

        let prefs = await TimerService.TimerPreferences.current()

        if let services = await AppServices.shared {
            await services.timerService.start(duration: duration, preset: presetTimer, preferences: prefs)
        } else {
            await startHeadlessTimer(duration: duration, preset: presetTimer, preferences: prefs)
        }
        return .result()
    }

    @MainActor
    private func startHeadlessTimer(
        duration: TimeInterval,
        preset: PresetTimer,
        preferences: TimerService.TimerPreferences
    ) async {
        let notificationService = NotificationService()
        let liveActivityService = LiveActivityService()
        let sharedStateService = SharedStateService()
        let alarmPlayer = AlarmPlayer()
        let alarmKitService = AlarmKitService()
        let screenTimeService = ScreenTimeService()
        let timerService = TimerService(
            notificationService: notificationService,
            liveActivityService: liveActivityService,
            sharedStateService: sharedStateService,
            alarmPlayer: alarmPlayer,
            alarmKitService: alarmKitService,
            screenTimeSessionScheduling: screenTimeService
        )

        await timerService.start(duration: duration, preset: preset, preferences: preferences)
    }
}
