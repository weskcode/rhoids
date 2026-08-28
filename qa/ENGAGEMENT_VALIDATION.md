# Reviews, Feedback, and Notification Validation

Use this checklist on the release candidate after unit tests pass. StoreKit,
notification delivery, and AlarmKit presentation are partly system-controlled,
so source and simulator coverage must be paired with a physical-device pass.

## Automated gates

- Run the full `RHOIDSTests` suite from a clean, private DerivedData directory.
- Confirm `ReviewPromptServiceTests`, `NotificationPermissionServiceTests`,
  `OnboardingPermissionTests`, and `TimerViewModelCompletionTests` pass.
- Build every target from `project.yml`: iPhone, widgets, Screen Time
  extensions, Watch app, and Watch widget.

## Review request

1. Install a fresh release build and complete onboarding.
2. Complete two timers on day one. Confirm no custom sentiment alert and no
   review sheet appears.
3. Complete a third timer on a different calendar day.
4. Confirm the timer-completion sheet remains the only prompt until dismissed.
5. Dismiss it. Confirm the app remains stable if StoreKit elects not to show a
   sheet; Apple controls whether a native sheet is displayed.
6. Complete more timers and relaunch repeatedly. Confirm RHOIDS does not prepare
   another opportunity during the 120-day cooldown.
7. In Settings, tap **Rate RHOIDS** and confirm the App Store opens directly to
   the production review composer (or the product page fallback).

## Feedback recovery

1. Open **Settings > Send Feedback** and enter a distinctive draft.
2. On a device with Mail available, tap **Send Feedback** and confirm the
   addressed composer opens.
3. On a configuration without an available mail handler, confirm the form stays
   open, the draft remains intact, and the support-email copy action works.
4. Check VoiceOver order, Dynamic Type at an accessibility size, Dark Mode, and
   Reduce Motion while the form and its error alert are visible.

## Notification permission and cadence

1. Fresh-install and open RHOIDS several times without starting a timer. Confirm
   no notification-permission prompt or custom launch nag appears.
2. From notification onboarding, choose **Not Now**. Relaunch repeatedly and
   confirm the app does not bombard the user.
3. Start a timer with alerts enabled. Confirm permission is requested in this
   task context and only once during that app session.
4. Deny permission, start more timers, and relaunch. Confirm no recurring custom
   permission alert appears; Settings remains the user-controlled recovery path.
5. Grant permission and verify completion, optional warning, sound, vibration,
   Ring/Silent, and Focus behavior on a physical device.
6. Confirm daily reminders remain off until explicitly enabled in Settings and
   that disabling them removes the pending reminder.

## AlarmKit and related device-only checks

- Confirm AlarmKit permission is not chained immediately after the onboarding
  notification permission sheet.
- Confirm the first alert-enabled timer requests AlarmKit contextually.
- Verify full-screen alarm presentation, cancellation, and no duplicate local
  notification on supported hardware.
- Repeat with Screen Time / Focus Lock enabled and with a paired Apple Watch to
  ensure system prompts and alerts do not overlap or duplicate one another.
