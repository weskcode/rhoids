# Physical Device Validation

Use this checklist before App Store submission or any PR that changes timer side effects, Live Activities, notifications, AlarmKit, Screen Time, widgets, watch connectivity, or app intents.

## Required Device Matrix

- iPhone with Dynamic Island, iOS 26.4 or newer.
- iPhone without Dynamic Island, iOS 26.4 or newer.
- Paired Apple Watch simulator or physical watch for watch handoff checks.

## Timer And Alert Flow

1. Start each preset from the main app.
2. Background the app immediately after start.
3. Confirm the timer remains visible through Live Activity or notification surfaces.
4. Confirm recurring warnings are delivered through local notifications when enabled.
5. Confirm there is no continuous or near-silent background audio playback.
6. Let the timer complete while the app is backgrounded.
7. Confirm AlarmKit appears when available; otherwise confirm the completion notification fires.
8. Open the app from the completion surface and dismiss the completion UI.
9. Confirm pending notifications, Live Activity, AlarmKit state, and shared widget state are cleared.

## Notification Actions

1. Start a timer and background the app.
2. From the completion notification, tap Dismiss.
3. Confirm the Live Activity ends and no alarm/audio remains active.
4. Start another timer and tap +1 min from the completion notification.
5. Confirm a 60-second snooze timer starts and all old completion alerts are removed.

## App Intents And Widgets

1. Start a specific preset from the widget-backed `StartTimerIntent` surface.
2. Confirm shared state, Live Activity, AlarmKit or fallback notification, Focus Lock scheduling, and app adoption match an in-app start.
3. Start the default timer from the home-screen widget.
4. Confirm the app opens and adopts the shared-state timer.
5. Stop from the app, widget, and Siri/Shortcuts surfaces.
6. Confirm every stop path clears shared state and pending notifications.

## Live Activity And Dynamic Island

1. Start a timer and swipe home.
2. Confirm compact, minimal, expanded, and Lock Screen presentations render real timer content.
3. Let the timer expire while the Dynamic Island is visible.
4. Confirm no black/blank pill appears and no widget extension crash is logged.
5. Capture `RHOIDSWidget` logs in Console.app if any surface is blank.

## Focus Lock

Detailed lifecycle expectations and the complete regression procedure live in
[`FOCUS_LOCK_VALIDATION.md`](FOCUS_LOCK_VALIDATION.md).

1. Deny Screen Time authorization and start a timer in Limited Scrolling mode.
2. Confirm completion copy does not claim apps will be blocked.
3. Grant Screen Time authorization and select at least one app/category.
4. Start a Limited Scrolling timer and background the app.
5. Confirm shields apply at timer completion and cooldown removes them.
6. Stop a timer early and confirm no delayed shielding occurs.

## Watch Handoff

1. Start from iPhone; confirm Watch receives the timer state.
2. Stop from Watch; confirm iPhone clears timer, notifications, Live Activity, and AlarmKit.
3. Start from Watch; confirm iPhone adopts the Watch end date without drift.
4. Complete from Watch-started state; confirm iPhone completion handling remains correct.
