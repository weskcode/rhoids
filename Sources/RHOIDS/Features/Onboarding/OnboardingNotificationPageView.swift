import SwiftUI

struct OnboardingNotificationPageView: View {
    let page: OnboardingPage
    let permissionService: NotificationPermissionService
    let notificationService: NotificationService

    @State private var permissionGranted: Bool?

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                OnboardingHeroView(page: page)
                features
                enableButton
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 40)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(page.features) { feature in
                OnboardingFeatureRow(feature: feature)
            }
        }
    }

    private var enableButton: some View {
        Button(action: requestPermissions) {
            Label(
                permissionButtonTitle,
                systemImage: permissionGranted == true ? "checkmark.circle.fill" : "bell.badge.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(permissionGranted != nil)
        .accessibilityHint(Text(permissionGranted != nil
            ? "Notification permission has already been requested."
            : "Requests permission to send timer alerts."))
    }

    private var permissionButtonTitle: String {
        switch permissionGranted {
        case true:
            "Notifications Enabled"
        case false:
            "Notifications Off"
        case nil:
            "Turn On Notifications"
        }
    }

    private func requestPermissions() {
        Task {
            let granted = await permissionService.requestPermission(using: notificationService)
            withAnimation { permissionGranted = granted }
        }
    }
}

#if DEBUG
#Preview {
    OnboardingNotificationPageView(
        page: .notifications,
        permissionService: NotificationPermissionService(),
        notificationService: NotificationService()
    )
}
#endif
