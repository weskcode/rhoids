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
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.dismiss) private var dismiss

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
        VStack(spacing: 8) {
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
        VStack(spacing: 8) {
            Spacer(minLength: 0)

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

            Spacer(minLength: 0)

            // Stop button - hidden in Always On (W-AO-01)
            if !isLuminanceReduced {
                stopButton
            }
        }
    }

    // MARK: - Completion

    private var completionContent: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.brand)
                .accessibilityHidden(true)

            Text("TIME’S UP")
                .font(.headline.bold())
                .accessibilityAddTraits(.isHeader)

            Text(viewModel.completionQuip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Spacer(minLength: 0)

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brand)
            .accessibilityLabel("Dismiss timer completion")
        }
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
                    lineWidth: 8
                )

            // Progress ring - trims from the leading edge so it drains clockwise
            Circle()
                .trim(from: progress, to: 1)
                .stroke(
                    Color.accentColor.opacity(isLuminanceReduced ? 0.3 : 1.0),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.4),
                    value: progress
                )

            // Countdown text
            VStack(spacing: 2) {
                if endDate > Date() {
                    // End date is in the future - show live countdown
                    Text(timerInterval: Date()...endDate, countsDown: true)
                        .font(.system(size: 32, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                } else {
                    // End date is in the past or invalid - show 0:00
                    Text("0:00")
                        .font(.system(size: 32, weight: .light, design: .rounded))
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
        .frame(width: 130, height: 130)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer progress")
        .accessibilityValue("\(Int((1 - progress) * 100)) percent remaining")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
