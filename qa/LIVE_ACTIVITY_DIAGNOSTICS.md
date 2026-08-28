# Live Activity Diagnostics

The shipping widget source must not contain `LiveActivityDiagnostics.useProbe` or probe-only branches. If a physical device shows a blank or black Dynamic Island pill, use this temporary local-only probe process instead of committing probe code.

## Probe Procedure

1. Create a throwaway branch.
2. Replace compact, minimal, expanded, and Lock Screen regions with static content:
   - Green `Circle`.
   - Static `Text("OK")`.
   - Static `ProgressView(value: 0.5)`.
3. Build and run on the affected physical device.
4. Start a timer, swipe home, and inspect Dynamic Island states.
5. Capture Console.app logs filtered to `RHOIDSWidget`.
6. Revert the probe before opening a PR.

## Result Interpretation

- Blank/black with static content: widget extension render or launch failure; inspect extension crash logs and entitlements.
- Shape appears but text does not: font/text rendering issue in the extension process.
- Static content works: the issue is likely timer-driven SwiftUI rendering; review `LiveActivityTimerRange`, `Text(timerInterval:)`, and progress range construction.

## Current Production Guardrails

- `LiveActivityTimerRange` clamps timer ranges before Dynamic Island rendering.
- Compact countdown uses a fixed width and monospaced digits.
- Expanded countdown uses `lineLimit(1)` and `minimumScaleFactor(0.6)`.
- Bottom progress uses `ProgressView(value:)` rather than a second timer-driven view.
