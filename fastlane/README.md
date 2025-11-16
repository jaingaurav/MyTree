## fastlane documentation

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac lint

```sh
[bundle exec] fastlane mac lint
```

Run all linting checks (SwiftLint + Markdown + Spelling)

### mac test

```sh
[bundle exec] fastlane mac test
```

Run all tests

### mac build_macos

```sh
[bundle exec] fastlane mac build_macos
```

Build macOS app (Release)

### mac build_macos_debug

```sh
[bundle exec] fastlane mac build_macos_debug
```

Build macOS app (Debug)

### mac build_ios

```sh
[bundle exec] fastlane mac build_ios
```

Build iOS app (Release)

### mac build_cli

```sh
[bundle exec] fastlane mac build_cli
```

Build CLI tool

### mac build_dmg

```sh
[bundle exec] fastlane mac build_dmg
```

Create DMG installer

### mac ci

```sh
[bundle exec] fastlane mac ci
```

Run full CI pipeline (lint + test + build)

### mac build_all

```sh
[bundle exec] fastlane mac build_all
```

Build all release artifacts (macOS, iOS, CLI, DMG)

### mac prepare_release

```sh
[bundle exec] fastlane mac prepare_release
```

Prepare release (version bump, tag, build artifacts)

### mac clean

```sh
[bundle exec] fastlane mac clean
```

Clean build artifacts

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
