# RHOIDS Release Readiness Checklist

Last updated: November 16, 2026

This document separates evidence the repository can prove from checks that require a signed physical device or App Store Connect. Passing local and CI tests is important, but it is not the same as release approval.

## Current Automated Evidence

### 1.1.4 build 9 release candidate

- The candidate includes the Science topic hub and reading pages from `3307ec1`.
- `project.yml` specifies 1.1.4 (9); XcodeGen regenerated the checked-in project.
- A fresh signed archive and App Store IPA export passed with Xcode 27.2.
- All seven exported bundles report 1.1.4 (9), have `get-task-allow` false, and pass strict recursive signature verification.
- All 14 added localization keys have translations in the 12 supported non-English locales.
- An independent source review found no actionable issues.
- All 778 iOS tests passed with no failures or skips on iPad Pro 11-inch (M5), iOS 27.2, with the simulator app reporting 1.1.4 (9).
- Settings navigation opened the Science hub and all five topic pages. Captures cover each page at normal text size and the hub and phone page at the largest accessibility size, in the iPhone compatibility window.
- Local watchOS tests are blocked by the missing runtime. A dedicated iPhone UI check remains pending because the stock iPhone simulator belongs to another active task.
- Xcode Cloud, physical-device checks, and TestFlight smoke checks remain pending. Build 9 has not been uploaded.

### Previously shipped builds

Recorded for the 1.1.3 update with Xcode 27.2:

- The iPhone suite passed 772 tests with no failures on an iPhone 18 Pro simulator running iOS 27.2, built from `fe9405c` (PR #11).
- Xcode Cloud iOS and watchOS tests passed on PR #11.
- The signed build 8 archive contains the same seven bundles as build 7. All seven report 1.1.3 (8), are signed with Apple Distribution and `get-task-allow` false, and pass `codesign --verify --deep --strict` in the exported IPA.
- Build 8 was archived from `fe9405c` and uploaded on November 15, 2026. App Store Connect reports it VALID, and it is in testing for the internal TestFlight group. The external group was not changed.
- App Store Connect now reports 1.1.3 with build 8 as READY_FOR_DISTRIBUTION.
- Physical-device and TestFlight smoke checks for build 8 remain pending. The iOS 26.0 floor check remains blocked by the local runtime policy.

Recorded for the 1.1.2 update with Xcode 27.2. Version 1.1.2 shipped with build 7:

- The iPhone suite passed 765 tests locally at the tree shipped in PR #4 (`7bc9a9f`).
- Xcode Cloud iOS and watchOS tests passed on PR #5 at `91c723e`, which adds the Watch app to the iPhone archive.
- The signed build 7 archive contains the iPhone app, Watch app, iPhone widget, complication, and three Screen Time extensions. All seven bundles report 1.1.2 (7). Companion bundle identifiers match, and `codesign --verify --deep --strict` passed.
- Build 7 was archived from the tree of `04fb1bf`, exported with an App Store distribution profile for each of the seven bundles, and uploaded on November 3, 2026. App Store Connect reports it VALID, and it is in the internal TestFlight group. It was attached to the 1.1.2 App Store version, which shipped. Build 6 lacks the Watch app and the completion fix, so it is superseded.
- The earlier Xcode Cloud repository-file test failures were fixed by bundling the required files under `RepoFiles/` (see `Tests/RHOIDSTests/Utilities/RepoFile.swift`). Subsequent iOS runs passed.
- The iOS 26.0 floor check remains blocked by the local runtime policy. Do not install a runtime to satisfy it without named approval.
- Simulator checks covered German onboarding, preset selection, timer start and early stop, completion, History, achievements, and Settings. Completion was also checked at the largest accessibility text size. Motion checks covered countdown formatting, the completion bounce, and Reduce Motion.
- Physical-device and TestFlight smoke checks remain pending. A successful archive does not prove these paths.

## Release Configuration

- Candidate marketing version: `1.1.4`
- Candidate build: `9`, archived and exported locally; not uploaded.
- Live version: `1.1.3` with build `8`. Builds `7` and `6` are superseded.
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
- The five iPhone screenshots in `AppStore/Screenshots/iphone-6.9/en-US/` are assigned to the intended screenshot slot and accepted without conversion errors. Upload them before submitting the version: Apple locks the screenshots once a version is released.
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
