# RHOIDS Release Readiness Checklist

Last updated: August 26, 2026

This document separates evidence the repository can prove from checks that require a signed physical device or App Store Connect. Passing local and CI tests is important, but it is not the same as release approval.

## Current Automated Evidence

- XcodeGen 2.45.4 regenerated `RHOIDS.xcodeproj` from `project.yml` successfully.
- The iPhone suite passed 746 tests across 70 suites on an iPhone simulator.
- The Apple Watch suite passed 24 tests across 3 suites on an Apple Watch simulator.
- GitHub Actions completed project discovery, the iPhone build, iPhone tests, and Apple Watch tests successfully for commit `2b60932`.
- The privacy manifest passes property-list validation and declares no tracking or collected data.
- The screenshot generator reproduced and validated ten opaque RGB PNGs with embedded sRGB metadata at 1284 by 2778 pixels.
- `git diff --check` and Python script compilation passed.

The local tests used Xcode beta because the machine's active developer directory pointed to Command Line Tools. CI independently passed with its hosted Xcode installation.

## Release Configuration

- Marketing version: `1.1.1`
- Build number: `4`
- Minimum iOS version: `26.4`
- Minimum watchOS version: `11.5`
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
