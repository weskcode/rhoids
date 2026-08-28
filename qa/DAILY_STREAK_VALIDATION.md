# Daily Streak and Reminder Validation

Last validated: July 20, 2026

## Product contract

- RHOIDS records one use when the app becomes active.
- Additional opens on the same local calendar day do not increase the streak.
- The current streak increases on consecutive local calendar days and resets to one after a missed day.
- The best streak never decreases. Achievement state is based on the best streak, so earned milestones stay earned.
- The seven visible milestones are 3, 7, 14, 30, 60, 100, and 365 days.
- Streak data stays on the device in `UserDefaults`; this first version does not add accounts, cloud sync, social features, or rewards.

## Reminder contract

- The reminder is off by default and is enabled only from Settings > Daily Use.
- Permission is requested in context when the user turns the reminder on.
- One repeating local notification uses the user's selected local time and the stable identifier `rhoids.daily.reminder`.
- Changing the time replaces the request without first deleting the last valid reminder. If replacement fails, the previous request remains scheduled and the in-app toggle turns off.
- Revoking notification permission in iOS Settings turns the in-app reminder toggle off when RHOIDS next becomes active.
- Daily-reminder cancellation and timer-alert cancellation are independent.

## Automated coverage

`DailyUseTrackerTests` verifies first use, same-day deduplication, consecutive days, month and year boundaries, daylight-saving time, missed-day reset, best-streak preservation, persistence, and milestone stability.

`NotificationSchedulingTests` verifies the stable identifier, selected time, replacement behavior, independent cancellation, timer-reminder separation, scheduling failure reporting, and preservation of the previous reminder after a failed replacement.

Full validation command:

```sh
xcodebuild test \
  -project RHOIDS.xcodeproj \
  -scheme RHOIDS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/rhoids-streak-final-derived-data
```

Release build command:

```sh
xcodebuild build \
  -project RHOIDS.xcodeproj \
  -scheme RHOIDS \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/rhoids-streak-final-release
```

## UI and accessibility matrix

- History empty state and populated-history layout
- Days Used Streak navigation and all seven achievement rows
- Reminder toggle, permission prompt, and time picker
- Light and Dark appearances
- Default, Extra Large, and largest Accessibility Dynamic Type sizes
- VoiceOver labels and singular/plural day wording
- Back navigation and tab-state preservation

The layouts use semantic text styles and colors, native `List`, `Form`, `NavigationLink`, `Toggle`, and `DatePicker` controls, 44-point minimum navigation rows, and stacked layouts at accessibility text sizes.

## External delivery boundary

Unit tests prove the request content and scheduling behavior, and Simulator testing proves the permission and settings flows. Final delivery by iOS while a physical phone is locked or the app is force-quit remains an operating-system/device integration check. Before an App Store submission, schedule a reminder a few minutes ahead on a physical device, lock the phone, verify delivery, then repeat after force-quitting RHOIDS and after changing the device time zone.
