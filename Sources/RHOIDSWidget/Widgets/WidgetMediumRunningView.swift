import SwiftUI
import WidgetKit

struct WidgetMediumRunningView: View {
    let endDate: Date
    let progressRange: ClosedRange<Date>
    var isAccented = false

    private var barColor: Color {
        isAccented ? .primary : .brand
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                WidgetAppIcon(size: 28, isAccented: isAccented)
                Text("RHOIDS")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Spacer()
                Text("Let's go!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(timerInterval: progressRange, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(barColor)
            .scaleEffect(y: 2.5)
            .frame(height: 20)

            Text(endDate, style: .timer)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("RHOIDS timer counting down")
    }
}
