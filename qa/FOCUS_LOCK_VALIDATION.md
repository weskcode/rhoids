# Focus Lock lifecycle and validation

This document is the source of truth for RHOIDS Limited Scrolling behavior.
Use it whenever timer scheduling, Screen Time extensions, notifications, or
shield copy changes.

## Expected user flow

1. The user chooses Limited Scrolling, authorizes Screen Time, selects apps or
   categories, and chooses a 5, 10, 15, or 30 minute cooldown.
2. Starting a timer records a one-shot Device Activity interval. If the timer
   is shorter than Apple's 15-minute monitoring minimum, RHOIDS uses the
   interval end-warning callback at the real timer deadline.
3. Natural timer completion applies the saved shields once. Early cancellation
   clears the pending shield intent before monitoring stops, so the stop
   callback cannot apply a stale shield.
4. Shield application persists the exact cooldown deadline. A 5- or 10-minute
   cooldown uses a valid 15-minute interval with an end-warning callback at the
   user's selected deadline. A 15- or 30-minute cooldown clears at interval end.
5. Cooldown completion clears Managed Settings, marks shields inactive, and
   delivers: “Cooldown complete: Nice work. Your selected apps are available
   again. Take a moment to recognize the break you gave yourself today.”
6. If a Device Activity callback is delayed, opening RHOIDS or pressing the
   shield action after the persisted deadline clears stale shields. On first
   launch after upgrading from a build that did not persist deadlines, RHOIDS
   also clears any legacy active shield with no deadline.
7. If the system rejects cooldown monitoring for any unexpected reason, RHOIDS
   fails open and removes the shield immediately rather than risk leaving the
   selected apps blocked without an automatic cleanup callback.

## Shield actions and copy

- Active title: **Cooldown in Progress**
- Explanation: **Your timer is finished. These apps will unlock automatically
  when your cooldown ends.**
- iOS 26.5 and later: **Open RHOIDS** uses the system
  `openParentalControlsApp` response.
- iOS 26.4: the shield presents a single **Close App** action because the
  system open-app response is unavailable.

The shield UI is system-rendered by ManagedSettingsUI. iOS owns its button hit
targets, safe-area behavior, VoiceOver semantics, and Dynamic Type layout.
RHOIDS supplies localized labels, semantic system gray/white colors, and the
brand green primary action color.

## Automated coverage

The iOS test target verifies:

- all supported cooldowns create valid intervals;
- short intervals use the correct warning offset;
- 15-minute and longer intervals unlock at interval end;
- early cancellation clears the pending shield intent;
- expired deadlines clear shield state;
- legacy shield state without a deadline is recovered;
- Limited Scrolling schedules the completion notification at timer end plus
  cooldown duration;
- Phone-Free mode does not schedule that notification;
- cancelling a timer removes the cooldown notification;
- shared suite, activity, store, mode, selection, and preference keys remain
  aligned across the host app and extensions.

The project has no XCUITest target. Existing Swift Testing suites cover adaptive
layout and accessibility-sensitive utilities, while Simulator launch inspection
covers the ordinary app shell. Simulator cannot grant production Family
Controls authorization or prove real shield presentation.

## Current verification record

Verified on July 20, 2026 with Xcode 26.5:

- The full `RHOIDS` iOS simulator suite passed 742 tests with 0 failures and
  0 skips on an iPhone 17 running iOS 26.5. The result includes the Focus Lock
  schedule, stale-shield recovery, early-cancellation, key-consistency, and
  cooldown-notification tests above.
- The full `RHOIDSWatchTests` simulator suite passed 23 tests with 0 failures
  on an Apple Watch SE 3 (40mm) running watchOS 26.5.
- A clean iOS simulator build and launch succeeded. The only emitted compiler
  warning was Xcode skipping App Intents metadata extraction for targets that
  do not link AppIntents; no source warning was emitted by this change.
- Runtime UI inspection on an iPhone 17 confirmed the welcome flow, Limited
  Scrolling selection, Screen Time permission handoff, timer screen, and
  Settings navigation render without clipped controls. Interactive controls
  exposed descriptive accessibility labels, including the full descriptions
  for Phone-Free and Limited Scrolling.

This record does not replace the signed-device procedure below. Simulator can
show Apple's authorization handoff, but it cannot prove extension delivery,
real app shielding, the shield's open-app response, or automatic unblocking on
a physical device.

## Required physical-device release test

Run on a signed iPhone with Screen Time authorization and notifications enabled:

1. Select one nonessential test app and a 5-minute cooldown.
2. Start the 3-minute timer, background RHOIDS, and leave the selected app open.
3. At timer completion, verify the selected app becomes shielded.
4. Verify the shield says **Cooldown in Progress**, **Open RHOIDS** opens RHOIDS
   on iOS 26.5+, and **Close App** exits the shielded app.
5. At five minutes, verify the selected app opens normally without manually
   disabling Focus Lock.
6. Verify the cooldown-complete notification appears once with the approved
   copy above.
7. Repeat with a 15-minute cooldown to exercise interval-end cleanup.
8. Start another timer and stop it early; wait beyond its original end time and
   verify no shield or cooldown notification appears.
9. Disable notifications and repeat once; automatic unblocking must still work,
   while the completion notification is correctly absent by user preference.

Record the device model, iOS version, app build, selected cooldowns, and result
in `qa/PHYSICAL_DEVICE_VALIDATION.md` before release.
