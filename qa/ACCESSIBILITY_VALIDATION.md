# Accessibility Validation

Use this checklist for every release candidate and for PRs that change SwiftUI layout, navigation, controls, widgets, or Live Activity UI.

## Dynamic Type

Run every screen at:

- Default.
- Extra Extra Extra Large.
- Accessibility Large.
- Accessibility Extra Extra Extra Large.

Required screens:

- Onboarding.
- Home.
- Running timer.
- Completion sheet.
- History empty and populated states.
- Settings.
- Focus Lock settings.
- Sound picker.
- Timer display picker.
- Tip Jar loading, empty, error, purchasing, and success states.
- About and Science.
- Home-screen widgets.
- Live Activity Lock Screen and Dynamic Island states.
- Watch app timer and settings surfaces.

Pass criteria:

- Primary actions remain visible and tappable.
- Timer digits scale without clipping.
- Labels do not overlap controls.
- Scrollable content remains reachable.
- No text is truncated unless the surrounding UI has a clear alternate label or accessibility value.

## VoiceOver

For each required screen:

- Swipe through the full screen in order.
- Confirm every button has a useful label.
- Confirm timer state exposes current status and remaining time.
- Confirm decorative imagery is hidden from VoiceOver.
- Confirm destructive actions announce their effect.
- Confirm modal/sheet dismissal is discoverable.

## Contrast And Motion

- Enable Increase Contrast and verify foreground/background contrast on all timer states, buttons, widgets, and Live Activity surfaces.
- Enable Reduce Motion and confirm timer transitions, onboarding, and completion UI avoid unnecessary animation.
- Confirm haptics and audio toggles do not rely on motion or color alone to communicate state.
