import SwiftUI

/// Timer running screen for Apple Watch.
///
/// HIG compliance:
/// - W-GL-06: Single piece of information (countdown) with clear hierarchy
/// - W-AO-01: Reduced complexity in Always On (ring dims, button hides)
/// - W-AO-03: TimelineView with .everyMinute in AOD
/// - W-AO-05: No layout shift between active/dimmed (ring stays, just dims)
/// - W-AC-01: All elements have accessibility labels
/// - W-AC-03: Ring has accessibility value with time remaining
/// - W-AC-04: Animations respect Reduce Motion
struct WatchTimerView: View {
    @Bindable var viewModel: WatchTimerViewModel
    @Environment(\.isLuminanceReduced) private var systemLuminanceReduced
    @Environment(\.dismiss) private var dismiss

    private var isLuminanceReduced: Bool {
#if DEBUG
        // Screenshot automation: force the Always On look to check that the
        // layout does not shift when the screen dims.
        if ProcessInfo.processInfo.environment["RHOIDS_DEMO_AOD"] == "1" { return true }
#endif
        return systemLuminanceReduced
    }

    var body: some View {
        Group {
            if isLuminanceReduced {
                TimelineView(.everyMinute) { _ in
                    timerContent
                }
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    timerContent
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Native bottom bar keeps the button clear of the screen edge.
            // Hidden in Always On (W-AO-01), but the item stays in place so
            // the ring does not shift when the screen dims (W-AO-05).
            ToolbarItem(placement: .bottomBar) {
                if viewModel.isComplete {
                    doneButton
                } else {
                    stopButton
                        .opacity(isLuminanceReduced ? 0 : 1)
                        .allowsHitTesting(!isLuminanceReduced)
                        .accessibilityHidden(isLuminanceReduced)
                }
            }
        }
        .onChange(of: viewModel.isComplete) { _, complete in
            if complete {
                // Stay on screen briefly then allow dismiss
            }
        }
        .onChange(of: viewModel.isCancelled) { _, cancelled in
            if cancelled {
                dismiss()
            }
        }
    }

    // MARK: - Timer Content

    private var timerContent: some View {
        Group {
            if viewModel.isComplete {
                completionContent
            } else {
                activeTimerContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Active Timer

    private var activeTimerContent: some View {
        VStack(spacing: 4) {
            // Ring + Countdown (W-AO-01: dims in AOD)
            WatchRingView(
                progress: viewModel.progress,
                endDate: viewModel.safeEndDate,
                isLuminanceReduced: isLuminanceReduced
            )

            // Preset name
            if !viewModel.presetName.isEmpty {
                Text(viewModel.presetName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Completion

    private var completionContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.brand)
                .accessibilityHidden(true)

            Text("TIME’S UP")
                .font(.headline.bold())
                .accessibilityAddTraits(.isHeader)

            Text(viewModel.completionQuip)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var doneButton: some View {
        Button(action: { dismiss() }) {
            Text("Done")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.brand)
    }

    // MARK: - Stop Button

    private var stopButton: some View {
        Button(role: .destructive, action: { viewModel.stopTimer() }) {
            Label("Stop", systemImage: "stop.fill")
                .font(.callout)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .accessibilityLabel("Stop timer early")
        .accessibilityHint("Double-tap to cancel the running timer")
    }
}

// MARK: - Watch Ring View

/// Circular progress ring optimized for Apple Watch.
///
/// - Shows countdown text centered inside
/// - Dims to 30% opacity in Always On Display
/// - Respects Reduce Motion for trim animation
struct WatchRingView: View {
    let progress: Double
    let endDate: Date
    let isLuminanceReduced: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(
                    Color(.darkGray).opacity(isLuminanceReduced ? 0.2 : 0.3),
                    lineWidth: 7
                )

            // Progress ring - trims from the leading edge so it drains clockwise
            Circle()
                .trim(from: progress, to: 1)
                .stroke(
                    Color.accentColor.opacity(isLuminanceReduced ? 0.3 : 1.0),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? nil : .linear(duration: 1),
                    value: progress
                )

            // Countdown text
            VStack(spacing: 2) {
                if endDate > Date() {
                    // End date is in the future - show live countdown
                    Text(timerInterval: Date()...endDate, countsDown: true)
                        .font(.system(size: 30, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                } else {
                    // End date is in the past or invalid - show 0:00
                    Text("0:00")
                        .font(.system(size: 30, weight: .light, design: .rounded))
                        .monospacedDigit()
                }

                if !isLuminanceReduced {
                    Text("\(Int((1 - progress) * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .containerRelativeFrame(.horizontal) { width, _ in width * 0.5 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer progress")
        .accessibilityValue("\(Int((1 - progress) * 100)) percent remaining")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
