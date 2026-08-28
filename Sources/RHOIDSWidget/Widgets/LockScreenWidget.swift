import WidgetKit
import SwiftUI
import RHOIDSShared

struct LockScreenWidget: Widget {
    let kind: String = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RHOIDSTimelineProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("RHOIDS Timer")
        .description("Track your bathroom timer.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct LockScreenWidgetView: View {
    let entry: RHOIDSEntry

    var body: some View {
        switch entry.family {
        case .accessoryCircular:
            if entry.isRunning, let endDate = entry.timerEndDate, endDate > entry.date {
                let timerRange = LiveActivityTimerRange(
                    endDate: endDate,
                    plannedDuration: entry.duration,
                    now: entry.date
                )
                ProgressView(timerInterval: timerRange.progress, countsDown: true) {
                    Image(systemName: "timer")
                        .font(.caption2)
                } currentValueLabel: {
                    Text(timerInterval: timerRange.remaining, countsDown: true)
                        .minimumScaleFactor(0.5)
                }
                .progressViewStyle(.circular)
            } else {
                Image(systemName: "timer")
            }

        case .accessoryRectangular:
            if entry.isRunning, let endDate = entry.timerEndDate, endDate > entry.date {
                HStack {
                    Image(systemName: "timer")
                    VStack(alignment: .leading) {
                        Text("RHOIDS")
                        Text(endDate, style: .timer)
                    }
                }
            } else {
                Text("Tap to start")
            }

        default:
            EmptyView()
        }
    }
}
