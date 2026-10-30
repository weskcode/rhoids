# Repository instructions

## iOS deployment and simulator policy

The deployment floor for owned iOS targets is iOS 26.0. Keep any higher explicit
minimum when required by the app. Use existing iOS 27.0 simulators for normal
tests and an existing iOS 26.0 runtime for deployment-floor checks.

Never download, install, restore, boot, or test iOS 18 or older simulator runtimes.
Do not run broad platform downloads, accept Xcode runtime-install prompts, or
install an old runtime to repair warnings or reproduce historical test evidence.
A missing destination blocks that check. Report it instead of fetching a runtime
or falling back to an older OS. Installing any other runtime requires named
approval of the exact version. Reuse devices; device creation, cloning, deletion,
and erasure require the owner's named approval. Pin test destinations to the
installed OS and use `-parallel-testing-enabled NO` to prevent test-device clones.
