import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var isActivatingTimer = false
    @State private var showScience = false
    @State private var widgetSetupExpanded = false
    @State private var toast: AppToast?
    @Namespace private var timerActivationNamespace
    @AppStorage(UserPreferences.timerStyleKey) private var timerStyle: TimerStyle = .card
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var screenTimeService: ScreenTimeService
    private let widgetSetupBottomID = "widgetSetupBottom"
    private let portraitScrollBottomPadding: CGFloat = 128

    init(services: AppServices) {
        _viewModel = State(initialValue: HomeViewModel(services: services))
        screenTimeService = services.screenTimeService
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let isLandscape = verticalSizeClass == .compact
                let isRegularWidth = horizontalSizeClass == .regular

                Group {
                    if viewModel.shouldShowTimer && !isActivatingTimer {
                        activeTimerView
                    } else if isLandscape {
                        landscapeLayout(size: geo.size)
                    } else {
                        portraitLayout(size: geo.size, isRegularWidth: isRegularWidth)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) {
                    if !viewModel.shouldShowTimer {
                        startButton
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                            .opacity(isActivatingTimer ? 0.55 : 1)
                            .transition(AppMotion.edgeFade(.bottom, reduceMotion: reduceMotion))
                    }
                }
            }
            .navigationTitle("RHOIDS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(viewModel.shouldShowTimer ? .hidden : .visible, for: .navigationBar)
            .toolbar(viewModel.shouldShowTimer ? .hidden : .visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showScience = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("The science behind RHOIDS")
                }
            }
            .navigationDestination(isPresented: $showScience) {
                ScienceView()
            }
            .safeAreaInset(edge: .top) {
                if screenTimeService.shieldsActive && !viewModel.shouldShowTimer {
                    FocusLockBanner {
                        screenTimeService.removeShields()
                        toast = AppToast(
                            message: String(localized: "Focus Lock turned off"),
                            systemImage: "lock.open"
                        )
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .task { await viewModel.checkPendingTimer() }
            .task { await viewModel.observeRemoteTimerStarts() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.checkPendingTimer() }
                    screenTimeService.refreshShieldsActiveState()
                }
            }
            .onChange(of: viewModel.shouldShowTimer) { _, isShowing in
                if !isShowing {
                    withAnimation(tabTransitionAnimation) {
                        isActivatingTimer = false
                    }
                }
            }
            .toast($toast, edge: .top)
        }
    }

    // MARK: - Portrait

    private func portraitLayout(size: CGSize, isRegularWidth: Bool) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 24) {
                    readyVisualization
                        .padding(.bottom, readyVisualizationBottomSpacing)

                    header
                        .transition(AppMotion.edgeFade(.top, reduceMotion: reduceMotion))

                    presetList
                        .accessibilityElement(children: .contain)
                        .transition(AppMotion.edgeFade(.bottom, reduceMotion: reduceMotion))

                    customDurationPicker
                        .opacity(viewModel.selectedPreset?.isCustom == true ? 1 : 0)
                        .frame(height: viewModel.selectedPreset?.isCustom == true ? nil : 0)
                        .clipped()
                        .allowsHitTesting(viewModel.selectedPreset?.isCustom == true)
                        .accessibilityHidden(viewModel.selectedPreset?.isCustom != true)

                    WidgetSetupChecklist(
                        expanded: $widgetSetupExpanded,
                        onExpand: {
                            withAnimation(AppMotion.contextChange(reduceMotion: reduceMotion)) {
                                scrollProxy.scrollTo(widgetSetupBottomID, anchor: .bottom)
                            }
                        }
                    )
                    .transition(AppMotion.edgeFade(.bottom, reduceMotion: reduceMotion))

                    Color.clear
                        .frame(height: 1)
                        .id(widgetSetupBottomID)
                }
                .opacity(isActivatingTimer ? 0.72 : 1)
                .frame(minHeight: max(size.height - 120, 0))
                .frame(maxWidth: isRegularWidth ? 560 : .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, portraitScrollBottomPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Landscape

    private func landscapeLayout(size: CGSize) -> some View {
        HStack(alignment: .center, spacing: size.width * 0.04) {
            readyVisualization
                .frame(maxWidth: .infinity)

            VStack(spacing: 16) {
                header
                presetList

                customDurationPicker
                    .opacity(viewModel.selectedPreset?.isCustom == true ? 1 : 0)
                    .frame(height: viewModel.selectedPreset?.isCustom == true ? nil : 0)
                    .clipped()
                    .allowsHitTesting(viewModel.selectedPreset?.isCustom == true)
                    .accessibilityHidden(viewModel.selectedPreset?.isCustom != true)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Components

    private var activeTimerView: some View {
        TimerRunningView(
            services: viewModel.services,
            activationNamespace: reduceMotion ? nil : timerActivationNamespace
        ) {
            withAnimation(tabTransitionAnimation) {
                viewModel.shouldShowTimer = false
                isActivatingTimer = false
            }
        }
        .transition(activeTimerTransition)
    }

    private var tabTransitionAnimation: Animation {
        AppMotion.contextChange(reduceMotion: reduceMotion)
    }

    private var liveTimerRevealAnimation: Animation {
        AppMotion.timerActivation(reduceMotion: reduceMotion)
    }

    private var activeTimerTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.992, anchor: .center))
    }

    private var previewPreset: PresetTimer {
        viewModel.startPreset
    }

    private var previewDuration: TimeInterval {
        previewPreset.isCustom ? viewModel.customDuration : previewPreset.duration
    }

    private var readyVisualization: some View {
        ReadyTimerVisualization(
            preset: previewPreset,
            duration: previewDuration,
            timerStyle: timerStyle,
            isPromoted: isActivatingTimer,
            activationNamespace: reduceMotion ? nil : timerActivationNamespace
        )
    }

    private var readyVisualizationBottomSpacing: CGFloat {
        timerStyle == .ring ? 24 : 0
    }

    private var header: some View {
        Text("How long do you need?")
            .font(.title2.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }

    private var presetList: some View {
        VStack(spacing: 4) {
            ForEach(PresetTimer.all) { preset in
                PresetRow(
                    preset: preset,
                    isSelected: viewModel.selectedPreset == preset
                ) {
                    selectPreset(preset)
                }
            }
        }
        .animation(AppMotion.optionSelection(reduceMotion: reduceMotion), value: viewModel.selectedPreset?.id)
    }

    private var customDurationPicker: some View {
        Stepper(value: $viewModel.customMinutes, in: 1 ... 30) {
            HStack {
                Text("Duration")
                    .font(.body)
                Spacer()
                Text("\(viewModel.customMinutes) min")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .accessibilityLabel("Custom duration in minutes")
        .accessibilityValue("\(viewModel.customMinutes) minutes")
    }

    private var startButton: some View {
        Button(action: {
            Task { await beginStartTimer() }
        }) {
            Label("Start Timer", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .disabled(isActivatingTimer)
    }

    private func selectPreset(_ preset: PresetTimer) {
        withAnimation(AppMotion.optionSelection(reduceMotion: reduceMotion)) {
            viewModel.selectedPreset = preset
        }
    }

    private func beginStartTimer() async {
        guard !isActivatingTimer, !viewModel.shouldShowTimer else { return }

        withAnimation(AppMotion.feedback(reduceMotion: reduceMotion)) {
            isActivatingTimer = true
        }

        let didStart = await viewModel.startTimer(presentTimer: false)
        guard didStart else {
            withAnimation(AppMotion.feedback(reduceMotion: reduceMotion)) {
                isActivatingTimer = false
            }
            return
        }

        withAnimation(liveTimerRevealAnimation) {
            viewModel.shouldShowTimer = true
            isActivatingTimer = false
        }
    }
}

#if DEBUG
#Preview {
    HomeView(services: .preview)
}
#endif
