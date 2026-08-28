import SwiftUI

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0
    @State private var focusModeChosen = false

    let notificationPermissionService: NotificationPermissionService
    let notificationService: NotificationService
    let screenTimeService: ScreenTimeService
    let onFinish: () -> Void

    private let pages = OnboardingPage.all

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    Group {
                        if page.id == OnboardingPage.focusMode.id {
                            OnboardingFocusModePageView(
                                page: page,
                                screenTimeService: screenTimeService,
                                onSelectionChanged: { focusModeChosen = $0 }
                            )
                        } else if page.id == OnboardingPage.notifications.id {
                            OnboardingNotificationPageView(
                                page: page,
                                permissionService: notificationPermissionService,
                                notificationService: notificationService
                            )
                        } else if page.id == OnboardingPage.makeItStick.id {
                            OnboardingWidgetPageView(page: page)
                        } else {
                            OnboardingPageView(page: page)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: advance) {
                Text(isLastPage ? "Get Started" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .disabled(continueDisabled)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .accessibilityHint(Text(isLastPage
                ? "Finishes the introduction and opens the app."
                : "Goes to the next page."))
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var isLastPage: Bool { currentPage == pages.count - 1 }

    private var isFocusModePage: Bool {
        pages[currentPage].id == OnboardingPage.focusMode.id
    }

    private var continueDisabled: Bool {
        isFocusModePage && !focusModeChosen
    }

    private func advance() {
        if isLastPage {
            onFinish()
        } else if reduceMotion {
            currentPage += 1
        } else {
            withAnimation(AppMotion.contextChange(reduceMotion: reduceMotion)) { currentPage += 1 }
        }
    }
}

#if DEBUG
#Preview {
    OnboardingView(
        notificationPermissionService: NotificationPermissionService(),
        notificationService: NotificationService(),
        screenTimeService: ScreenTimeService(),
        onFinish: {}
    )
}
#endif
