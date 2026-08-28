import SwiftUI

struct OnboardingWidgetPageView: View {
    let page: OnboardingPage
    @State private var visibleCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                OnboardingHeroView(page: page)
                steps
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 40)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { animateSteps() }
        .onDisappear { visibleCount = 0 }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(Array(page.features.enumerated()), id: \.element.id) { index, feature in
                let isVisible = index < visibleCount

                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.tint.opacity(0.12))
                            .frame(width: 44, height: 44)

                        if feature.symbol == "applewatch" {
                            Image(systemName: feature.symbol)
                                .font(.title2)
                                .foregroundStyle(.tint)
                        } else {
                            Text("\(index + 1)")
                                .font(.body.bold().monospacedDigit())
                                .foregroundStyle(.tint)
                        }
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(feature.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(feature.title). \(feature.description)")
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 16)
            }
        }
    }

    private func animateSteps() {
        let stepDelay: Duration = reduceMotion ? .zero : .milliseconds(400)
        let animation = AppMotion.contextChange(reduceMotion: reduceMotion)

        for index in 0 ..< page.features.count {
            Task {
                try? await Task.sleep(for: stepDelay * index)
                withAnimation(animation) { visibleCount = index + 1 }
            }
        }
    }
}

#if DEBUG
#Preview {
    OnboardingWidgetPageView(page: .makeItStick)
}
#endif
