# RHOIDS Release Readiness Checklist

Last updated: November 2, 2026

This document separates evidence the repository can prove from checks that require a signed physical device or App Store Connect. Passing local and CI tests is important, but it is not the same as release approval.

## Current Automated Evidence

Recorded November 2, 2026 for the 1.1.2 release branch with Xcode 27.2 and XcodeGen 2.46.0:

- The iPhone suite passed 764 tests with no failures or skips on an iPhone 17e simulator running iOS 27.2.
- The `RHOIDS` scheme built for the simulator, and a Release build for a generic iOS device succeeded with code signing disabled.
- The Apple Watch suite passed in Xcode Cloud (PR Check) on Apple Watch Series 10 and Ultra 2 simulators. It was not run locally because the release machine has no watchOS simulator runtime.
- The iPhone suite failed in Xcode Cloud with 19 `.projectRootNotFound` errors from `LiveActivityDeviceDiagnosticTests`, `LocalizationCatalogTests`, and `TipJarServiceTests`. Those tests read repository files at run time, and Xcode Cloud runs tests on a host without the repository. The test bundle now carries copies of those files under `RepoFiles/` (see `Tests/RHOIDSTests/Utilities/RepoFile.swift`).
- No iOS 26.0 runtime was available, so the deployment-floor check is still open.
- The app was exercised in German on the simulator: onboarding, preset selection, a timer start and early stop, the completion sheet, History, streak achievements, and Settings. The completion sheet was also checked at the largest accessibility text size.
- The privacy manifest passes property-list validation and declares no tracking or collected data.
- `git diff --check` passed.

## Release Configuration

- Marketing version: `1.1.2`
- Build number: `5`, uploaded to TestFlight on November 2, 2026. `project.yml` now holds `6`, which the archive post-action prepared for the next upload.
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
- All five consumable tip products exist, have complete metadata and review screenshots, and are attached to the submitted app version.
- App privacy answers match the shipped binary: no tracking and no collected data.
- The hosted privacy-policy URL shows the current text from `PRIVACY.md`.
- The ten iPhone screenshots are assigned to the intended screenshot slot and accepted without conversion errors.
- App name, subtitle, description, categories, age rating, support URL, and copyright are current.
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
