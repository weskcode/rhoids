import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                OnboardingHeroView(page: page)

                VStack(alignment: .leading, spacing: 28) {
                    ForEach(page.features) { feature in
                        OnboardingFeatureRow(feature: feature)
                    }
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
    }
}

#if DEBUG
#Preview {
    OnboardingPageView(page: .theRule)
}
#endif
