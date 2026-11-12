# RHOIDS Release Readiness Checklist

Last updated: November 12, 2026

This document separates evidence the repository can prove from checks that require a signed physical device or App Store Connect. Passing local and CI tests is important, but it is not the same as release approval.

## Current Automated Evidence

Recorded for the 1.1.2 update with Xcode 27.2:

- The iPhone suite passed 765 tests locally at the tree shipped in PR #4 (`7bc9a9f`).
- Xcode Cloud iOS and watchOS tests passed on PR #5 at `91c723e`, which adds the Watch app to the iPhone archive.
- The signed build 7 archive contains the iPhone app, Watch app, iPhone widget, complication, and three Screen Time extensions. All seven bundles report 1.1.2 (7). Companion bundle identifiers match, and `codesign --verify --deep --strict` passed.
- Build 7 was archived from the tree of `04fb1bf`, exported with an App Store distribution profile for each of the seven bundles, and uploaded on November 3, 2026. App Store Connect reports it VALID, and it is in the internal TestFlight group. It is attached to the 1.1.2 draft with manual release selected. Build 6 lacks the Watch app and the completion fix, so it is superseded.
- The earlier Xcode Cloud repository-file test failures were fixed by bundling the required files under `RepoFiles/` (see `Tests/RHOIDSTests/Utilities/RepoFile.swift`). Subsequent iOS runs passed.
- The iOS 26.0 floor check remains blocked by the local runtime policy. Do not install a runtime to satisfy it without named approval.
- Simulator checks covered German onboarding, preset selection, timer start and early stop, completion, History, achievements, and Settings. Completion was also checked at the largest accessibility text size. Motion checks covered countdown formatting, the completion bounce, and Reduce Motion.
- Physical-device and TestFlight smoke checks remain pending. A successful archive does not prove these paths.

## Release Configuration

- Marketing version: `1.1.2`
- Uploaded build: `7`, attached to the App Store draft. Build `6` is superseded.
- Watch packaging correction: PR #5, `91c723e`. The archive post-action prepares the next build number locally, so the working copy may show a higher number than the uploaded build.
- Minimum iOS version: `26.0`
- Minimum watchOS version: `26.0`
- iPhone bundle identifier: `com.wesley.RHOIDS`
- App Group: `group.com.wesley.RHOIDS`
- Supported native products: iPhone app, iPhone widgets and Live Activity, Apple Watch app, watch complications, and Screen Time extensions
- Native iPad and Mac targets: not included

`project.yml` is the source of truth. Regenerate the Xcode project after changing target membership, versioning, signing, or build settings.

## Physical Device Gates

Complete these checks on signed hardware before release:

- AlarmKit authorization and full-screen completion presentation
- Notification sound, haptics, warning timing, and delivery while locked or force-quit
- Live Activity and Dynamic Island layout throughout a complete timer
- Focus Lock authorization, selected-app shielding, cooldown persistence, and recovery after relaunch
- Widget and Siri timer starts with the app closed
- iPhone and Apple Watch start, stop, synchronization, and haptic behavior
- VoiceOver on every user flow
- Dynamic Type at the largest accessibility sizes
- Reduce Motion and Increase Contrast
- StoreKit sandbox purchase, pending purchase, cancellation, and failure recovery
- Launch performance, memory growth, and leaks on a representative device

Use the focused guides in this directory for App Intents, accessibility, Focus Lock, daily streaks, Live Activities, and physical-device validation.

## App Store Connect Gates

Confirm these items in App Store Connect:

- The selected build matches the intended marketing version and build number.
- Coffee Tip is the only product currently configured in App Store Connect. Verify it loads and purchases successfully in the sandbox. The other four configured product identifiers are unavailable; adding products requires separate approval.
- App privacy answers match the shipped binary: no tracking and no collected data.
- The hosted privacy-policy URL shows the current text from `PRIVACY.md`.
- The ten iPhone screenshots are assigned to the intended screenshot slot and accepted without conversion errors.
- Four Apple Watch screenshots (416 x 496) are assigned to the Series 10 slot. App Review requires a Watch screenshot because the build embeds the Watch app.
- App name, subtitle, description, categories, age rating, support URL, and copyright are current. The age-rating fields `socialMedia` and `socialMediaAgeRestricted` remain unanswered.
- Export compliance, signing, provisioning, Family Controls entitlement approval, and App Review notes are complete.

## Final Signoff

Release only when:

- [ ] The working tree is clean and the release commit is pushed.
- [ ] CI is green for the exact release commit.
- [ ] Every physical-device gate above has a named tester, date, device, OS version, and result.
- [ ] App Store Connect metadata and in-app purchases are complete.
- [ ] The archive is built with the intended release toolchain and validates successfully.
- [ ] TestFlight smoke testing passes on the processed build.
- [ ] Known limitations are documented honestly in App Review notes and release notes.
