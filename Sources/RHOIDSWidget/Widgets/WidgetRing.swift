import SwiftUI

struct WidgetRing: View {
    let progress: Double
    var isAccented = false

    private let ringSize: CGFloat = 88
    private let lineWidth: CGFloat = 6

    private var ringColor: Color {
        isAccented ? .primary : .brand
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("R")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(width: ringSize, height: ringSize)
    }
}
