import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var titleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    let showGetStarted: Bool
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 48) {
                Spacer()

                Text(verbatim: "RHOIDS")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if showGetStarted {
                    Button(action: onComplete) {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .padding(.horizontal, 32)
                    .opacity(buttonOpacity)
                    .accessibilityHint(Text("Begins the introduction."))
                }

                Spacer()
                    .frame(height: 20)
            }
            .opacity(titleOpacity)
        }
        .task { await runIntro() }
    }

    @MainActor
    private func runIntro() async {
        if reduceMotion {
            titleOpacity = 1
            if showGetStarted {
                buttonOpacity = 1
            } else {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                onComplete()
            }
            return
        }

        withAnimation(AppMotion.reveal(reduceMotion: reduceMotion)) {
            titleOpacity = 1
        }

        try? await Task.sleep(for: .milliseconds(880))
        guard !Task.isCancelled else { return }

        if showGetStarted {
            withAnimation(AppMotion.reveal(reduceMotion: reduceMotion)) {
                buttonOpacity = 1
            }
        } else {
            await fadeOut()
        }
    }

    @MainActor
    private func fadeOut() async {
        withAnimation(AppMotion.reveal(reduceMotion: reduceMotion)) {
            titleOpacity = 0
        }
        try? await Task.sleep(for: .milliseconds(280))
        guard !Task.isCancelled else { return }
        onComplete()
    }
}

#Preview("First Launch") { SplashView(showGetStarted: true, onComplete: {}) }
#Preview("Returning") { SplashView(showGetStarted: false, onComplete: {}) }
