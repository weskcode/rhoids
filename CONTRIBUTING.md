# Contributing to RHOIDS

RHOIDS is intentionally narrow in scope. Contributions should improve correctness, accessibility, maintainability, localization, or release quality without expanding the product into a general wellness platform.

## Before Making Changes

1. Read `README.md`, `project.yml`, and the relevant guidance in `qa/`.
2. Run `scripts/install_git_hooks.sh` once after cloning to enable repository commit-message checks.
3. Start from a clean branch and preserve unrelated local work.
4. Search for existing tests and shared helpers before introducing new abstractions.
5. Keep changes small enough to review and validate as one coherent unit.

## Local Fork Setup

The repository contains the identifiers used by the shipping app so the checked-in Xcode project remains reproducible. Contributors must use identifiers owned by their Apple Developer team:

1. Update the development team and bundle identifiers in `project.yml`.
2. Replace the App Group in each entitlement file and `Sources/Shared/SharedStateKeys.swift`.
3. Regenerate `RHOIDS.xcodeproj` with XcodeGen.
4. Confirm that the iPhone, widget, Watch, complication, and Screen Time extension targets use the intended signing configuration.

Family Controls access is granted by Apple. Contributors without that entitlement can review and test unrelated code, but should not claim that Focus Lock works on a physical device.

`project.yml` is the source of truth for targets, build settings, versioning, and source membership. Run `xcodegen generate` after changing it and include the resulting `RHOIDS.xcodeproj` update in the same commit.

## Engineering Expectations

- Use Swift 6 concurrency-safe APIs and respect existing actor boundaries.
- Prefer system SwiftUI components, semantic colors, SF Symbols, Dynamic Type, and Reduce Motion-aware behavior.
- Preserve VoiceOver labels, hints, traits, and minimum touch targets.
- Keep user data local unless a feature explicitly requires an Apple system service.
- Do not add third-party dependencies without a clear, documented need.
- Do not commit DerivedData, result bundles, archives, credentials, signing assets, local IDE state, or generated media experiments.
- Add focused regression tests for behavior changes.

## Validation

Before submitting a change:

1. Regenerate the project when required.
2. Run `git diff --check`.
3. Build the affected schemes.
4. Run the relevant iPhone and/or Apple Watch tests.
5. Perform the appropriate manual checks from `qa/` for changed system integrations.
6. Describe what was run and distinguish simulator evidence from physical-device and distribution evidence.

Screen Time, AlarmKit, Live Activities, notification delivery, Apple Watch handoff, signing, and App Store behavior require additional device or external verification. A successful simulator build is not evidence that those gates passed.

## Pull Requests

Keep pull requests focused. Explain the user-visible effect, important implementation decisions, validation performed, and any remaining device or release gates. Do not include unrelated formatting, generated caches, historical reports, or marketing experiments.

By contributing, you agree that your contribution is licensed under the repository's MIT License. Do not submit code, media, translations, or other material that you do not have permission to redistribute.

## Commit Messages

Commit messages must be professional, concise, and free of emoji, pictographs, decorative Unicode symbols, and emoji presentation characters. This applies to the subject and body, including commits created by automated tools. Conventional Commit prefixes are permitted but optional. Do not include AI attribution or generated-by trailers unless a human contributor explicitly requests them.

The tracked `commit-msg` hook enforces this locally after `scripts/install_git_hooks.sh` is run. CI applies the same validator to every commit introduced by a pull request or protected-branch push.
