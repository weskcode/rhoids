import ActivityKit
import SwiftUI
import SwiftData

struct TimerRunningView: View {
    @State private var viewModel: TimerViewModel
    @State private var isStopping = false
    @AppStorage(UserPreferences.timerStyleKey) private var timerStyle: TimerStyle = .card
    @Environment(\.modelContext) private var modelContext
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let activationNamespace: Namespace.ID?
    private let onFinished: () -> Void

    init(
        services: AppServices,
        activationNamespace: Namespace.ID? = nil,
        onFinished: @escaping () -> Void = {}
    ) {
        self.activationNamespace = activationNamespace
        self.onFinished = onFinished
        self._viewModel = State(initialValue: TimerViewModel(
            timerService: services.timerService,
            alarmPlayer: services.alarmPlayer,
            sharedStateService: services.sharedStateService,
            liveActivityService: services.liveActivityService,
            alarmKitService: services.alarmKitService,
            screenTimeService: services.screenTimeService,
            reviewPromptService: services.reviewPromptService
        ))
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = verticalSizeClass == .compact

            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if isLandscape {
                    landscapeLayout(size: geo.size)
                } else {
                    portraitLayout(size: geo.size)
                }
            }
        }
        .interactiveDismissDisabled()
        .sheet(item: $viewModel.outcome, onDismiss: {
            viewModel.completionDismissed()
        }) { outcome in
            TimerCompleteView(outcome: outcome)
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                onFinished()
            }
        }
#if DEBUG
        .overlay(alignment: .top) {
            if ProcessInfo.processInfo.environment["RHOIDS_LIVE_ACTIVITY_DEBUG"] == "1" {
                LiveActivityDebugBanner()
            }
        }
#endif
        .task {
            viewModel.setModelContext(modelContext)
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Layouts

    private func portraitLayout(size: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            RunningTimerVisualization(
                viewModel: viewModel,
                timerStyle: timerStyle,
                maxWidth: max(min(size.width - 48, 400), 0),
                isStopping: isStopping,
                reduceMotion: reduceMotion,
                activationNamespace: activationNamespace
            )

            Text(viewModel.focusModeCaption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 32)

            Spacer(minLength: 0)

            StopTimerButton(
                isStopping: isStopping,
                reduceMotion: reduceMotion,
                action: beginStopTimer
            )
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func landscapeLayout(size: CGSize) -> some View {
        HStack(spacing: 32) {
            RunningTimerVisualization(
                viewModel: viewModel,
                timerStyle: timerStyle,
                maxWidth: max(min(size.width * 0.45, 360), 0),
                isStopping: isStopping,
                reduceMotion: reduceMotion,
                activationNamespace: activationNamespace
            )
                .frame(maxWidth: .infinity)

            VStack(spacing: 16) {
                Text(viewModel.focusModeCaption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                StopTimerButton(
                    isStopping: isStopping,
                    reduceMotion: reduceMotion,
                    action: beginStopTimer
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func beginStopTimer() {
        guard !isStopping else { return }
        withAnimation(stopAnimation) {
            isStopping = true
        } completion: {
            viewModel.stopTimer()
        }
    }

    private var stopAnimation: Animation {
        AppMotion.feedback(reduceMotion: reduceMotion)
    }
}

private struct RunningTimerVisualization: View {
    let viewModel: TimerViewModel
    let timerStyle: TimerStyle
    let maxWidth: CGFloat
    let isStopping: Bool
    let reduceMotion: Bool
    let activationNamespace: Namespace.ID?

    private var safeWidth: CGFloat {
        (maxWidth.isFinite && maxWidth > 0) ? maxWidth : 300
    }

    private var shouldApplyGlobalStopAnimation: Bool {
        isStopping && timerStyle != .card
    }

    private var isReady: Bool {
        viewModel.plannedDuration > 0
    }

    var body: some View {
        ZStack {
            if isReady {
                TimelineView(.periodic(from: .now, by: timelineInterval)) { context in
                    timerContent(progress: progress(at: context.date))
                }
                    .transition(.opacity)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: safeWidth)
        .timerActivationGeometry(activationNamespace)
        .scaleEffect(!reduceMotion && shouldApplyGlobalStopAnimation ? 0.96 : 1)
        .opacity(shouldApplyGlobalStopAnimation ? 0.72 : 1)
        .animation(AppMotion.feedback(reduceMotion: reduceMotion), value: isStopping)
        .animation(AppMotion.reveal(reduceMotion: reduceMotion), value: isReady)
    }

    private func progress(at date: Date) -> Double {
        guard viewModel.plannedDuration > 0 else { return 0 }
        if viewModel.isCountdownFrozen {
            return viewModel.progress
        }
        let elapsed = max(date.timeIntervalSince(viewModel.startDate), 0)
        return min(max(elapsed / viewModel.plannedDuration, 0), 1)
    }

    private var timelineInterval: TimeInterval {
        reduceMotion ? 1 : 0.25
    }

    @ViewBuilder
    private func timerContent(progress: Double) -> some View {
        switch timerStyle {
        case .card:
            CardTimerView(
                endDate: viewModel.safeEndDate,
                progress: progress,
                isStopping: isStopping,
                frozenRemaining: viewModel.frozenRemaining
            )
        case .ring:
            RingTimerView(
                endDate: viewModel.safeEndDate,
                progress: progress,
                frozenRemaining: viewModel.frozenRemaining
            )
        case .progress:
            ProgressTimerView(
                endDate: viewModel.safeEndDate,
                progress: progress,
                frozenRemaining: viewModel.frozenRemaining
            )
        case .flip:
            FlipTimerView(
                endDate: viewModel.safeEndDate,
                progress: progress,
                frozenRemaining: viewModel.frozenRemaining
            )
        case .dial:
            DialTimerView(
                endDate: viewModel.safeEndDate,
                progress: progress,
                frozenRemaining: viewModel.frozenRemaining
            )
        case .gauge:
            GaugeTimerView(
                endDate: viewModel.safeEndDate,
                progress: progress,
                frozenRemaining: viewModel.frozenRemaining
            )
        }
    }
}

private struct StopTimerButton: View {
    let isStopping: Bool
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(isStopping ? "Stopping" : "Stop Early", systemImage: isStopping ? "stop.circle.fill" : "stop.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.large)
        .frame(maxWidth: 360)
        .disabled(isStopping)
        .scaleEffect(reduceMotion ? 1 : (isStopping ? 0.97 : 1))
        .animation(AppMotion.feedback(reduceMotion: reduceMotion), value: isStopping)
        .accessibilityInputLabels(["Stop Timer", "Stop Early"])
    }
}

// MARK: - Live Activity Debug Banner
// Debug-only diagnostics; enable with RHOIDS_LIVE_ACTIVITY_DEBUG=1.

#if DEBUG
private struct LiveActivityDebugBanner: View {
    @State private var status = ""

    var body: some View {
        Text(status)
            .font(.caption2.monospaced())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.7), in: .capsule)
            .padding(.top, 8)
            .task {
                await refreshStatus()
            }
            .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
                Task { await refreshStatus() }
            }
    }

    private func refreshStatus() async {
        let auth = ActivityAuthorizationInfo()
        let activities = Activity<RHOIDSActivityAttributes>.activities
        let states = activities.map { String(describing: $0.activityState) }
        status = "LA: enabled=\(auth.areActivitiesEnabled) count=\(activities.count) \(states.joined(separator: ","))"
    }
}
#endif

#if DEBUG
#Preview {
    TimerRunningView(services: .preview)
}
#endif
