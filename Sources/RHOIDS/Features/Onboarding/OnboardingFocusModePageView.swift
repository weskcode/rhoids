import SwiftUI
import FamilyControls

/// Lets the user pick how RHOIDS keeps them off their phone: Phone-Free
/// (just a reminder) or Limited Scrolling (Screen Time blocks a chosen set
/// of apps once the timer ends). The choice is required to continue and is
/// persisted immediately, so backgrounding mid-onboarding doesn't lose it.
///
/// Limited Scrolling requests Screen Time authorization *and* app selection
/// right here, inline - Continue only requires picking a path, not finishing
/// the app picker, since denying/skipping just resolves to the "blocking
/// won't engage" effective-mode fallback rather than a dead end.
struct OnboardingFocusModePageView: View {
    let page: OnboardingPage
    @Bindable var screenTimeService: ScreenTimeService
    /// Reports back to `OnboardingView` so the Continue button can require a
    /// selection before advancing past this page.
    let onSelectionChanged: (Bool) -> Void

    @State private var selectedMode: FocusLockMode?
    @State private var authErrorMessage: String?
    @State private var isRequestingAuthorization = false
    @State private var showingAppPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                OnboardingHeroView(page: page)

                VStack(spacing: 16) {
                    FocusModeCard(
                        symbol: "iphone.slash",
                        title: String(localized: "Phone-Free"),
                        description: String(localized: "Set your phone down when the timer starts. We'll remind you. Nothing to set up."),
                        isSelected: selectedMode == .phoneFree,
                        action: { select(.phoneFree) }
                    )

                    FocusModeCard(
                        symbol: "lock.iphone",
                        title: String(localized: "Limited Scrolling"),
                        description: String(localized: "Use a few apps during your timer. We'll lock them with a cooldown once time's up."),
                        isSelected: selectedMode == .limitedScrolling,
                        action: { select(.limitedScrolling) }
                    )
                }

                if selectedMode == .limitedScrolling {
                    limitedScrollingDetail
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 40)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            onSelectionChanged(selectedMode != nil)
        }
        .sheet(isPresented: $showingAppPicker) {
            NavigationStack {
                FamilyActivityPicker(
                    headerText: String(localized: "Choose apps to block when your timer ends."),
                    footerText: String(localized: "You can change this anytime in Settings."),
                    selection: $screenTimeService.selection
                )
                .navigationTitle("Blocked Apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingAppPicker = false }
                    }
                }
                .onChange(of: screenTimeService.selection) {
                    screenTimeService.saveSelection()
                }
            }
        }
    }

    @ViewBuilder
    private var limitedScrollingDetail: some View {
        if let authErrorMessage {
            Text(authErrorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        } else if isRequestingAuthorization {
            ProgressView()
        } else {
            Button(action: { showingAppPicker = true }) {
                HStack {
                    Image(systemName: "apps.iphone")
                    Text("Choose Apps to Block")
                    Spacer()
                    Text(appCountLabel)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
    }

    private var appCountLabel: String {
        let count = screenTimeService.selection.applicationTokens.count
            + screenTimeService.selection.categoryTokens.count
        if count == 0 { return String(localized: "None") }
        return String(localized: "\(count) selected")
    }

    private func select(_ mode: FocusLockMode) {
        selectedMode = mode
        FocusLockPreferences.shared.mode = mode
        onSelectionChanged(true)

        guard mode == .limitedScrolling else {
            FocusLockPreferences.shared.isEnabled = false
            authErrorMessage = nil
            return
        }

        authErrorMessage = nil
        isRequestingAuthorization = true
        Task {
            do {
                try await screenTimeService.requestAuthorization()
                FocusLockPreferences.shared.isEnabled = true
            } catch {
                // Non-blocking: the user's chosen intent still saves. They
                // can grant Screen Time access later from Settings, where
                // the same authorization flow is offered again.
                authErrorMessage = String(localized: "Screen Time authorization was denied. You can enable it later in Settings \u{2192} Screen Time.")
            }
            isRequestingAuthorization = false
        }
    }
}

private struct FocusModeCard: View {
    let symbol: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36, height: 36, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel("\(title). \(description)")
    }
}

#if DEBUG
#Preview {
    OnboardingFocusModePageView(
        page: .focusMode,
        screenTimeService: ScreenTimeService(),
        onSelectionChanged: { _ in }
    )
}
#endif
