import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct WatchTimerEntry: TimelineEntry {
    let date: Date
    let isRunning: Bool
    let endDate: Date?
    let presetName: String?
    let duration: TimeInterval

    var progress: Double {
        guard isRunning, let endDate, duration > 0 else { return 0 }
        let elapsed = duration - endDate.timeIntervalSince(date)
        return min(max(elapsed / duration, 0), 1)
    }

    var remaining: TimeInterval {
        guard let endDate else { return 0 }
        return max(endDate.timeIntervalSince(date), 0)
    }

    static let placeholder = WatchTimerEntry(
        date: Date(),
        isRunning: false,
        endDate: nil,
        presetName: nil,
        duration: 0
    )

    static let previewRunning = WatchTimerEntry(
        date: Date(),
        isRunning: true,
        endDate: Date().addingTimeInterval(120),
        presetName: "Recommended",
        duration: 180
    )
}

// MARK: - Timeline Provider

struct WatchTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchTimerEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchTimerEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchTimerEntry>) -> Void) {
        let entry = currentEntry()

        if entry.isRunning, let endDate = entry.endDate {
            // Create entries leading up to completion
            var entries: [WatchTimerEntry] = [entry]
            let remaining = endDate.timeIntervalSince(Date())
            let interval: TimeInterval = remaining > 60 ? 30 : 10

            var nextDate = Date().addingTimeInterval(interval)
            while nextDate < endDate {
                entries.append(WatchTimerEntry(
                    date: nextDate,
                    isRunning: true,
                    endDate: endDate,
                    presetName: entry.presetName,
                    duration: entry.duration
                ))
                nextDate = nextDate.addingTimeInterval(interval)
            }

            // Final entry at completion
            entries.append(WatchTimerEntry(
                date: endDate,
                isRunning: false,
                endDate: nil,
                presetName: nil,
                duration: 0
            ))

            completion(Timeline(entries: entries, policy: .after(endDate)))
        } else {
            // Idle - refresh in 15 minutes
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func currentEntry() -> WatchTimerEntry {
        let defaults = UserDefaults(suiteName: SharedStateKeys.suiteName) ?? .standard
        let isRunning = defaults.bool(forKey: SharedStateKeys.timerIsRunning)
        let endDate = defaults.object(forKey: SharedStateKeys.timerEndDate) as? Date
        let presetName = defaults.string(forKey: SharedStateKeys.timerPresetName)
        let duration = defaults.double(forKey: SharedStateKeys.timerDuration)

        return WatchTimerEntry(
            date: Date(),
            isRunning: isRunning && (endDate ?? .distantPast) > Date(),
            endDate: endDate,
            presetName: presetName,
            duration: duration
        )
    }
}

// MARK: - Widget Definition

/// Supports all 4 complication families per W-CP-01.
struct RHOIDSWatchComplication: Widget {
    let kind = "RHOIDSWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchTimerProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("RHOIDS Timer")
        .description("Track your bathroom timer at a glance.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Complication Views

struct ComplicationView: View {
    let entry: WatchTimerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    // MARK: - Circular (W-CP-02: works tinted + full color)

    private var circularView: some View {
        Group {
            if entry.isRunning {
                Gauge(value: 1 - entry.progress) {
                    Image(systemName: "timer")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetURL(URL(string: "rhoids://timer"))
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                    Text("Start")
                        .font(.system(size: 10))
                }
                .widgetURL(URL(string: "rhoids://start"))
            }
        }
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Corner

    private var cornerView: some View {
        Group {
            if entry.isRunning, let endDate = entry.endDate {
                Text(timerInterval: entry.date...endDate, countsDown: true)
                    .font(.caption.monospacedDigit())
                    .widgetCurvesContent()
                    .widgetURL(URL(string: "rhoids://timer"))
            } else {
                Image(systemName: "timer")
                    .widgetURL(URL(string: "rhoids://start"))
            }
        }
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Rectangular (multi-line detail)

    private var rectangularView: some View {
        Group {
            if entry.isRunning, let endDate = entry.endDate {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "timer")
                        Text(entry.presetName ?? "Timer")
                            .font(.caption.bold())
                    }

                    ProgressView(
                        timerInterval: Date()...max(endDate, Date()),
                        countsDown: true
                    )
                    .tint(.accentColor)

                    Text(timerInterval: entry.date...endDate, countsDown: true)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .widgetURL(URL(string: "rhoids://timer"))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "timer")
                        Text("RHOIDS")
                            .font(.caption.bold())
                    }
                    Text("Tap to start timer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .widgetURL(URL(string: "rhoids://start"))
            }
        }
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Inline (text only, W-CP-04: meaningful without context)

    private var inlineView: some View {
        Group {
            if entry.isRunning, let endDate = entry.endDate {
                Text("RHOIDS \u{00B7} \(Text(timerInterval: entry.date...endDate, countsDown: true))")
                    .widgetURL(URL(string: "rhoids://timer"))
            } else {
                Text("RHOIDS \u{00B7} Ready")
                    .widgetURL(URL(string: "rhoids://start"))
            }
        }
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Accessibility (W-CP-04)

    private var accessibilityDescription: String {
        if entry.isRunning {
            let mins = Int(entry.remaining) / 60
            let secs = Int(entry.remaining) % 60
            return "RHOIDS timer, \(mins) minutes \(secs) seconds remaining"
        } else {
            return "RHOIDS timer, ready to start"
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Circular Running", as: .accessoryCircular) {
    RHOIDSWatchComplication()
} timeline: {
    WatchTimerEntry.previewRunning
}

#Preview("Circular Idle", as: .accessoryCircular) {
    RHOIDSWatchComplication()
} timeline: {
    WatchTimerEntry.placeholder
}

#Preview("Rectangular Running", as: .accessoryRectangular) {
    RHOIDSWatchComplication()
} timeline: {
    WatchTimerEntry.previewRunning
}
#endif
