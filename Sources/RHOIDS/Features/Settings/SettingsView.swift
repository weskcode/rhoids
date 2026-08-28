import ActivityKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    // Stored in the App Group so the widget extension can read the default.
    @AppStorage("defaultPreset", store: UserDefaults(suiteName: PresetPreferences.suiteName))
    private var defaultPreset = PresetTimer.recommended.id.uuidString
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("warningEnabled") private var warningEnabled = true
    @AppStorage(UserPreferences.warningModeKey) private var warningMode: WarningMode = .endOnly
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage(UserPreferences.timerStyleKey) private var timerStyle: TimerStyle = .card
    @AppStorage("dailyReminderEnabled.v1") private var dailyReminderEnabled = false
    @AppStorage("dailyReminderHour.v1") private var dailyReminderHour = 9
    @AppStorage("dailyReminderMinute.v1") private var dailyReminderMinute = 0

    @State private var alarmSelection: AlarmSound = SoundPreferences.alarm
    @State private var warningSelection: AlarmSound = SoundPreferences.warning
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @State private var showingFeedback = false
    @State private var reminderUpdateTask: Task<Void, Never>?

    var screenTimeService: ScreenTimeService
    var tipJarService: TipJarService
    var notificationService: NotificationService

    var body: some View {
        NavigationStack {
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

                Section("Appearance") {
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

                Section("Feedback") {
                    Toggle("Haptics", isOn: $hapticsEnabled)

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

                FocusLockSettingsView(screenTimeService: screenTimeService)

                Section("Background") {
                    NavigationLink("The Science") { ScienceView() }
                    NavigationLink("About RHOIDS") { AboutView() }
                }

                TipJarSection(tipJarService: tipJarService)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingFeedback) {
                FeedbackFormView()
            }
            .task { await refreshSettingsStatus() }
            .onAppear { refreshLiveActivitiesStatus() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refreshSettingsStatus() }
            }
            .onChange(of: notificationsEnabled) { _, isEnabled in
                Task { @MainActor in
                    guard let services = AppServices.shared else { return }
                    if !isEnabled {
                        await services.alarmPlayer.stopAlarm()
                    }
                    await services.timerService.rescheduleForFocusLockChange()
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

    private func openRateRHOIDS() {
        guard let writeReviewURL = AppStoreInfo.writeReviewURL else { return }
        openURL(writeReviewURL) { accepted in
            guard !accepted, let productURL = AppStoreInfo.productURL else { return }
            openURL(productURL)
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
