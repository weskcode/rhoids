import ActivityKit
import SwiftUI
import UserNotifications

/// Settings is a short hub. Each row opens a page named for its job.
struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase

    // Read here only to show each row's current value.
    @AppStorage("defaultPreset", store: UserDefaults(suiteName: PresetPreferences.suiteName))
    private var defaultPreset = PresetTimer.recommended.id.uuidString
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage(
        FocusLockPreferences.modeKey,
        store: UserDefaults(suiteName: SharedStateKeys.suiteName)
    ) private var focusLockMode: FocusLockMode = .phoneFree

    var screenTimeService: ScreenTimeService
    var tipJarService: TipJarService
    var notificationService: NotificationService

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        TimerSettingsPage()
                    } label: {
                        SettingsHubRow(
                            title: "Timer",
                            value: defaultPresetName,
                            systemImage: "timer",
                            tint: .green
                        )
                    }

                    NavigationLink {
                        NotificationSettingsPage(notificationService: notificationService)
                    } label: {
                        SettingsHubRow(
                            title: "Notifications",
                            value: nil,
                            systemImage: "bell.badge.fill",
                            tint: .red
                        )
                    }

                    NavigationLink {
                        Form { FocusLockSettingsView(screenTimeService: screenTimeService) }
                            .navigationTitle("Bathroom Mode")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        SettingsHubRow(
                            title: "Bathroom Mode",
                            value: focusLockModeName,
                            systemImage: "lock.fill",
                            tint: .indigo
                        )
                    }

                    NavigationLink {
                        AppearanceSettingsPage()
                    } label: {
                        SettingsHubRow(
                            title: "Appearance",
                            value: appearanceMode.displayName,
                            systemImage: "paintbrush.fill",
                            tint: .blue
                        )
                    }
                }

                Section {
                    NavigationLink {
                        FeedbackSettingsPage(tipJarService: tipJarService)
                    } label: {
                        SettingsHubRow(
                            title: "Feedback",
                            value: nil,
                            systemImage: "bubble.left.fill",
                            tint: .orange
                        )
                    }

                    NavigationLink {
                        ScienceView()
                    } label: {
                        SettingsHubRow(
                            title: "The Science",
                            value: nil,
                            systemImage: "text.book.closed.fill",
                            tint: .gray
                        )
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsHubRow(
                            title: "About RHOIDS",
                            value: nil,
                            systemImage: "info.circle.fill",
                            tint: .gray
                        )
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await DailyReminderPermissionSync.reconcile(notificationService) }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await DailyReminderPermissionSync.reconcile(notificationService) }
            }
        }
    }

    private var defaultPresetName: String {
        PresetTimer.all.first { $0.id.uuidString == defaultPreset }?.name
            ?? PresetTimer.recommended.name
    }

    private var focusLockModeName: String {
        switch focusLockMode {
        case .phoneFree: String(localized: "Phone-Free")
        case .limitedScrolling: String(localized: "Limited Scrolling")
        }
    }
}

/// A Settings-style row: a tinted SF Symbol tile, the title, and an optional current value.
private struct SettingsHubRow: View {
    let title: LocalizedStringKey
    let value: String?
    let systemImage: String
    let tint: Color

    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 29
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: tileSize, height: tileSize)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                // At accessibility sizes the value would squeeze the title, so it goes underneath.
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let value {
                        Text(value)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(title)
                if let value {
                    Spacer()
                    Text(value)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Keeps the daily reminder honest when notification access is revoked in iOS Settings,
/// whichever Settings page happens to be showing.
private let dailyReminderEnabledKey = "dailyReminderEnabled.v1"

@MainActor
private enum DailyReminderPermissionSync {
    static func reconcile(_ notificationService: NotificationService) async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let defaults = UserDefaults.standard
        guard status == .denied, defaults.bool(forKey: dailyReminderEnabledKey) else { return }
        defaults.set(false, forKey: dailyReminderEnabledKey)
        await notificationService.cancelDailyReminder()
    }
}

private struct TimerSettingsPage: View {
    @AppStorage("defaultPreset", store: UserDefaults(suiteName: PresetPreferences.suiteName))
    private var defaultPreset = PresetTimer.recommended.id.uuidString
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        Form {
            Section {
                Picker("Default Timer", selection: $defaultPreset) {
                    ForEach(PresetTimer.all) { preset in
                        Text(preset.name).tag(preset.id.uuidString)
                    }
                }
            } header: {
                Text("Defaults")
            } footer: {
                Text("Used by the Home Screen widget and Siri shortcut when you start a timer without picking one.")
            }

            Section {
                Toggle("Haptics", isOn: $hapticsEnabled)
            }
        }
        .navigationTitle("Timer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppearanceSettingsPage: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage(UserPreferences.timerStyleKey) private var timerStyle: TimerStyle = .card

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                NavigationLink {
                    TimerDisplayPickerView()
                } label: {
                    HStack {
                        Text("Timer Display")
                        Spacer()
                        Text(timerStyle.displayName)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FeedbackSettingsPage: View {
    @Environment(\.openURL) private var openURL

    @State private var showingFeedback = false

    var tipJarService: TipJarService

    var body: some View {
        Form {
            Section {
                Button {
                    openRateRHOIDS()
                } label: {
                    Label("Rate RHOIDS", systemImage: "star.bubble")
                }

                Button {
                    showingFeedback = true
                } label: {
                    Label("Send Feedback", systemImage: "envelope")
                }
            }

            TipJarSection(tipJarService: tipJarService)
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFeedback) {
            FeedbackFormView()
        }
    }

    private func openRateRHOIDS() {
        guard let writeReviewURL = AppStoreInfo.writeReviewURL else { return }
        openURL(writeReviewURL) { accepted in
            guard !accepted, let productURL = AppStoreInfo.productURL else { return }
            openURL(productURL)
        }
    }
}

private struct NotificationSettingsPage: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("warningEnabled") private var warningEnabled = true
    @AppStorage(UserPreferences.warningModeKey) private var warningMode: WarningMode = .endOnly
    @AppStorage(dailyReminderEnabledKey) private var dailyReminderEnabled = false
    @AppStorage("dailyReminderHour.v1") private var dailyReminderHour = 9
    @AppStorage("dailyReminderMinute.v1") private var dailyReminderMinute = 0

    @State private var alarmSelection: AlarmSound = SoundPreferences.alarm
    @State private var warningSelection: AlarmSound = SoundPreferences.warning
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @State private var reminderUpdateTask: Task<Void, Never>?

    var notificationService: NotificationService

    var body: some View {
        Form {
            Section {
                Toggle("Timer Alerts", isOn: $notificationsEnabled)

                if notificationsEnabled {
                    NavigationLink {
                        SoundPicker(title: "Alarm Sound", selection: $alarmSelection)
                            .onChange(of: alarmSelection) { _, new in
                                SoundPreferences.alarm = new
                            }
                    } label: {
                        HStack {
                            Text("Alarm Sound")
                            Spacer()
                            Text(alarmSelection.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Toggle("30-Second Warning", isOn: $warningEnabled)
                    .disabled(!notificationsEnabled)

                if notificationsEnabled && warningEnabled {
                    Picker("Warning Mode", selection: $warningMode) {
                        ForEach(WarningMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    NavigationLink {
                        SoundPicker(title: "Warning Sound", selection: $warningSelection)
                            .onChange(of: warningSelection) { _, new in
                                SoundPreferences.warning = new
                            }
                    } label: {
                        HStack {
                            Text("Warning Sound")
                            Spacer()
                            Text(warningSelection.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Notifications")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    permissionFooter
                    if notificationsEnabled && warningEnabled {
                        Text(warningMode.settingsDescription)
                    }
                }
            }

            Section {
                Toggle("Daily Reminder", isOn: $dailyReminderEnabled)

                if dailyReminderEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("Daily Use")
            } footer: {
                if permissionStatus == .denied {
                    Text("Notifications are turned off for RHOIDS. Enable them in Settings to use a daily reminder.")
                        .foregroundStyle(.red)
                } else {
                    Text("A single daily reminder to open RHOIDS and keep your usage streak going.")
                }
            }

            if !liveActivitiesEnabled {
                Section {
                    HStack {
                        Text("Dynamic Island / Lock Screen")
                        Spacer()
                        Text("Disabled")
                            .foregroundStyle(.red)
                    }
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                } header: {
                    Text("Live Activities")
                } footer: {
                    Text("Live Activities are disabled for RHOIDS. Enable them in Settings > RHOIDS > Live Activities to see the timer on your Lock Screen and Dynamic Island.")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshSettingsStatus() }
        .onAppear { refreshLiveActivitiesStatus() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshSettingsStatus() }
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            Task { @MainActor in
                guard let services = AppServices.shared else { return }
                if isEnabled {
                    // Pick up alerts for whatever is currently running.
                    await services.timerService.rescheduleForFocusLockChange()
                } else {
                    // Routed through TimerService (not called directly
                    // on the individual services) so the cancellation
                    // waits for any in-flight AlarmKit/notification
                    // scheduling to land first - see
                    // cancelAlertsForNotificationsDisabled()'s doc
                    // comment for why that ordering matters.
                    await services.timerService.cancelAlertsForNotificationsDisabled()
                }
            }
        }
        .onChange(of: dailyReminderEnabled) { _, isEnabled in
            replaceReminderUpdateTask {
                await updateDailyReminder(isEnabled: isEnabled)
            }
        }
        .onChange(of: dailyReminderHour) { _, _ in
            guard dailyReminderEnabled else { return }
            replaceReminderUpdateTask {
                await rescheduleDailyReminder()
            }
        }
        .onChange(of: dailyReminderMinute) { _, _ in
            guard dailyReminderEnabled else { return }
            replaceReminderUpdateTask {
                await rescheduleDailyReminder()
            }
        }
        .onDisappear { reminderUpdateTask?.cancel() }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: dailyReminderHour,
                minute: dailyReminderMinute,
                second: 0,
                of: Date()
            ) ?? Date()
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            dailyReminderHour = components.hour ?? 9
            dailyReminderMinute = components.minute ?? 0
        }
    }

    @ViewBuilder
    private var permissionFooter: some View {
        switch permissionStatus {
        case .denied:
            Text("Notifications are turned off for RHOIDS. Enable them in Settings to hear the alarm.")
                .foregroundStyle(.red)
        case .notDetermined:
            Text("RHOIDS will request notification permission the first time you start a timer.")
        case .authorized, .provisional, .ephemeral:
            Text("Alarms play even when the app is closed or your phone is locked. The Ring/Silent switch still mutes default sounds.")
        @unknown default:
            EmptyView()
        }
    }

    private func refreshPermissionStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        permissionStatus = status

        // The user can revoke notification access in Settings while RHOIDS is
        // backgrounded. Keep the in-app switch honest when they return.
        if status == .denied, dailyReminderEnabled {
            dailyReminderEnabled = false
            await notificationService.cancelDailyReminder()
        }
    }

    @MainActor
    private func updateDailyReminder(isEnabled: Bool) async {
        guard isEnabled else {
            await notificationService.cancelDailyReminder()
            return
        }

        do {
            let authorized = try await notificationService.requestAuthorization()
            guard !Task.isCancelled, dailyReminderEnabled, authorized else {
                if Task.isCancelled { return }
                dailyReminderEnabled = false
                await refreshPermissionStatus()
                return
            }
            let scheduled = await scheduleDailyReminder()
            guard !Task.isCancelled, dailyReminderEnabled, scheduled else {
                if Task.isCancelled { return }
                dailyReminderEnabled = false
                return
            }
            await refreshPermissionStatus()
        } catch {
            dailyReminderEnabled = false
            await refreshPermissionStatus()
        }
    }

    private func scheduleDailyReminder() async -> Bool {
        await notificationService.scheduleDailyReminder(
            hour: dailyReminderHour,
            minute: dailyReminderMinute
        )
    }

    @MainActor
    private func rescheduleDailyReminder() async {
        guard dailyReminderEnabled else { return }
        let scheduled = await scheduleDailyReminder()
        guard !Task.isCancelled, dailyReminderEnabled else { return }
        if !scheduled {
            dailyReminderEnabled = false
        }
    }

    @MainActor
    private func replaceReminderUpdateTask(
        operation: @escaping @MainActor @Sendable () async -> Void
    ) {
        reminderUpdateTask?.cancel()
        reminderUpdateTask = Task { await operation() }
    }

    @MainActor
    private func refreshSettingsStatus() async {
        refreshLiveActivitiesStatus()
        await refreshPermissionStatus()
    }

    @MainActor
    private func refreshLiveActivitiesStatus() {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }
}

#if DEBUG
    #Preview {
        SettingsView(
            screenTimeService: ScreenTimeService(),
            tipJarService: TipJarService(),
            notificationService: NotificationService()
        )
    }
#endif
