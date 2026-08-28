import ActivityKit
import os.log
import RHOIDSShared
import WidgetKit
import SwiftUI

private let log = Logger(subsystem: "com.wesley.RHOIDS.widget", category: "LiveActivityWidget")

struct RHOIDSLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RHOIDSActivityAttributes.self) { context in
            // Lock Screen banner. An explicit background tint + foreground
            // color guarantees a defined surface - without them the banner can
            // render as bare transparent/black on a physical device (the
            // simulator silently supplies a default that masks the bug).
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.brand)
        } dynamicIsland: { context in
            // Build guaranteed-valid countdown + progress ranges. An end date
            // that has already passed would otherwise form an inverted
            // ClosedRange that traps while the system renders the snapshot,
            // blanking the ENTIRE Dynamic Island (every region is pre-rendered
            // for the snapshot, including the expanded one, even when only the
            // compact pill is on screen). See `LiveActivityTimerRange`.
            let range = LiveActivityTimerRange(
                endDate: context.state.endDate,
                plannedDuration: context.attributes.plannedDuration
            )

            return DynamicIsland {
                // MARK: - Expanded (user long-presses the pill)
                DynamicIslandExpandedRegion(.leading) {
                    Label("RHOIDS", systemImage: "timer")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Single, prominent countdown. `minimumScaleFactor`
                    // guarantees the digits are never clipped in the narrow
                    // trailing region.
                    Text(timerInterval: range.remaining, countsDown: true)
                        .monospacedDigit()
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Keep the Dynamic Island snapshot path as small and
                    // deterministic as possible. The compact countdown
                    // remains live; this bar updates on each snapshot
                    // without using another timer-driven SwiftUI view.
                    ProgressView(value: range.fractionComplete)
                        .tint(.green)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(timerInterval: range.remaining, countsDown: true)
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .frame(width: 56, alignment: .trailing)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Lock Screen

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<RHOIDSActivityAttributes>

    private var endDate: Date { context.state.endDate }
    private var isRunning: Bool { !context.isStale && endDate > .now }

    var body: some View {
        let _ = log.info("LockScreenLiveActivityView rendering - isStale=\(context.isStale), endDate=\(endDate), isRunning=\(isRunning)")
        if isRunning {
            RunningLiveActivityContent(
                endDate: endDate,
                plannedDuration: context.attributes.plannedDuration
            )
        } else {
            CompletedLiveActivityContent()
        }
    }
}

struct RunningLiveActivityContent: View {
    let endDate: Date
    let plannedDuration: TimeInterval

    var body: some View {
        // Guaranteed-valid ranges. Prevents a fatal ClosedRange trap when the
        // timer expires between the `isRunning` check and this body's
        // evaluation. See `LiveActivityTimerRange`.
        let range = LiveActivityTimerRange(
            endDate: endDate,
            plannedDuration: plannedDuration
        )

        return VStack(spacing: 12) {
            HStack {
                Text("RHOIDS")
                    .font(.subheadline.bold())
                    .foregroundStyle(.brand)
                Spacer()
                Text("LET'S GO!")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text(timerInterval: range.remaining, countsDown: true)
                .font(.title.monospacedDigit().bold())
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .center)

            // Bare progress bar - hide ProgressView's built-in time label so it
            // doesn't duplicate the countdown above.
            ProgressView(timerInterval: range.progress, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.brand)
        }
        .padding()
    }
}

struct CompletedLiveActivityContent: View {
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.brand)
                Text("Time's up!")
                    .font(.headline)
            }
            Text("Open RHOIDS to dismiss")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Previews

#if DEBUG
extension RHOIDSActivityAttributes {
    fileprivate static var preview: RHOIDSActivityAttributes {
        RHOIDSActivityAttributes(plannedDuration: 180, presetIcon: "checkmark.seal")
    }
}

extension RHOIDSActivityAttributes.ContentState {
    /// Mid-run state (~2:45 remaining of a 3:00 timer).
    fileprivate static var running: RHOIDSActivityAttributes.ContentState {
        RHOIDSActivityAttributes.ContentState(
            endDate: .now.addingTimeInterval(165),
            presetName: "Recommended"
        )
    }

    /// Expired state - exercises the range-clamping guard.
    fileprivate static var finished: RHOIDSActivityAttributes.ContentState {
        RHOIDSActivityAttributes.ContentState(
            endDate: .now.addingTimeInterval(-5),
            presetName: "Recommended"
        )
    }
}

#Preview("Dynamic Island - Expanded", as: .dynamicIsland(.expanded), using: RHOIDSActivityAttributes.preview) {
    RHOIDSLiveActivityWidget()
} contentStates: {
    RHOIDSActivityAttributes.ContentState.running
    RHOIDSActivityAttributes.ContentState.finished
}

#Preview("Dynamic Island - Compact", as: .dynamicIsland(.compact), using: RHOIDSActivityAttributes.preview) {
    RHOIDSLiveActivityWidget()
} contentStates: {
    RHOIDSActivityAttributes.ContentState.running
}

#Preview("Dynamic Island - Minimal", as: .dynamicIsland(.minimal), using: RHOIDSActivityAttributes.preview) {
    RHOIDSLiveActivityWidget()
} contentStates: {
    RHOIDSActivityAttributes.ContentState.running
}

#Preview("Lock Screen", as: .content, using: RHOIDSActivityAttributes.preview) {
    RHOIDSLiveActivityWidget()
} contentStates: {
    RHOIDSActivityAttributes.ContentState.running
    RHOIDSActivityAttributes.ContentState.finished
}
#endif
