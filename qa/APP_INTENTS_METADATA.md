# App Intents Metadata Triage

Xcode runs App Intents metadata extraction for multiple targets in the `RHOIDS` scheme. Some targets intentionally contain no App Intents symbols, so messages such as `Extracted no relevant App Intents symbols, skipping writing output` are informational for those targets.

## Expected Intent Owners

- `RHOIDS` app target: owns `StartTimerIntent`, `StopTimerIntent`, `TimerPresetEntity`, and `RHOIDSAppShortcuts`.
- Widget/default-timer shared code: owns `StartDefaultTimerIntent` and app-group state seeding.
- Watch and test bundles: no App Shortcuts are expected unless new watch-specific shortcuts are added.

## Blocking Conditions

Treat the build as blocked if:

- The `RHOIDS` app target fails App Intents metadata extraction.
- The shortcuts do not appear in Shortcuts or Siri after install.
- `StartTimerIntent` starts a timer without the same side effects as an in-app start.
- `StopTimerIntent` leaves shared state, notifications, Live Activity, or AlarmKit state armed.

## Verification Steps

1. Run an iOS build and save the full build log.
2. Confirm App Intents metadata extraction runs for the `RHOIDS` app target without errors.
3. Install on a physical device.
4. Open Shortcuts and verify RHOIDS actions are discoverable.
5. Run `Start RHOIDS Timer` with a non-default preset.
6. Confirm shared state, Live Activity, AlarmKit or fallback notification, and Focus Lock scheduling match an in-app start.
7. Run the stop action and confirm all timer side effects are cleared.

## Non-Blocking Messages

Messages that a watch, widget, or test bundle has no relevant App Intents symbols are not release blockers by themselves. Keep them in build logs for auditability, but do not suppress metadata extraction globally unless a target-specific build setting is proven safe on the current Xcode toolchain.
