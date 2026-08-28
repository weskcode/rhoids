import WidgetKit
import SwiftUI
import RHOIDSShared

struct HomeScreenWidget: Widget {
    let kind: String = "HomeScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RHOIDSTimelineProvider()) { entry in
            HomeScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("RHOIDS Timer")
        .description("Start a bathroom timer with one tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HomeScreenWidgetView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetFamily) private var family
    let entry: RHOIDSEntry

    var body: some View {
        Group {
            if entry.isRunning, let endDate = entry.timerEndDate, endDate > entry.date {
                let timerRange = LiveActivityTimerRange(
                    endDate: endDate,
                    plannedDuration: entry.duration,
                    now: entry.date
                )
                switch family {
                case .systemMedium:
                    WidgetMediumRunningView(
                        endDate: endDate,
                        progressRange: timerRange.progress,
                        isAccented: renderingMode == .accented
                    )
                default:
                    WidgetSmallRunningView(
                        endDate: endDate,
                        isAccented: renderingMode == .accented
                    )
                }
            } else {
                switch family {
                case .systemMedium:
                    WidgetMediumIdleView(isAccented: renderingMode == .accented)
                default:
                    WidgetSmallIdleView(isAccented: renderingMode == .accented)
                }
            }
        }
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

// MARK: - Small Running

struct WidgetSmallRunningView: View {
    let endDate: Date
    var isAccented = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                WidgetAppIcon(size: 24, isAccented: isAccented)
                Text("RHOIDS")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer(minLength: 0)

            Text(endDate, style: .timer)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Spacer(minLength: 0)

            Text("Let's go!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("RHOIDS timer counting down")
    }
}

// MARK: - Small Idle

struct WidgetSmallIdleView: View {
    var isAccented = false

    var body: some View {
        Button(intent: StartDefaultTimerIntent()) {
            VStack(spacing: 10) {
                WidgetAppIcon(size: 52, isAccented: isAccented)

                Text("RHOIDS")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))

                Text("Tap to start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start default RHOIDS timer")
        .accessibilityHint("Opens RHOIDS and starts your configured default timer.")
    }
}

#if DEBUG
#Preview("Idle - Small", as: .systemSmall) {
    HomeScreenWidget()
} timeline: {
    RHOIDSEntry(date: .now, timerEndDate: nil, presetName: nil, isRunning: false, duration: 0)
}

#Preview("Running - Small", as: .systemSmall) {
    HomeScreenWidget()
} timeline: {
    RHOIDSEntry(date: .now, timerEndDate: .now.addingTimeInterval(176), presetName: "Recommended", isRunning: true, duration: 180)
}

#Preview("Idle - Medium", as: .systemMedium) {
    HomeScreenWidget()
} timeline: {
    RHOIDSEntry(date: .now, timerEndDate: nil, presetName: nil, isRunning: false, duration: 0, family: .systemMedium)
}

#Preview("Running - Medium", as: .systemMedium) {
    HomeScreenWidget()
} timeline: {
    RHOIDSEntry(date: .now, timerEndDate: .now.addingTimeInterval(176), presetName: "Recommended", isRunning: true, duration: 180, family: .systemMedium)
}
#endif
