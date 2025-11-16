# Developer Documentation

MyTree is a macOS/iOS family tree visualization app using SwiftUI and MVVM architecture.

## Getting Started

### Initial Setup

```bash
git clone https://github.com/jaingaurav/MyTree
cd MyTree
make setup    # Install all dependencies (Fastlane, linting tools, git hooks)
make macos    # Build macOS app
make test     # Run tests
```

The `make setup` command automatically installs:

- Fastlane and Ruby dependencies
- Markdown linting tools (markdownlint-cli2, cspell, markdown-link-check)
- SwiftLint
- Git hooks for pre-commit checks

### Prerequisites

- **macOS 12.0+** (Monterey or later)
- **Xcode 14.0+** with Swift 5.7+
- **Command Line Tools**: `xcode-select --install`
- **Ruby 2.7+**: Pre-installed on macOS, or `brew install ruby`
- **Optional - Node.js**: For markdown linting (`brew install node`)
- **Optional - Homebrew**: For SwiftLint (`brew install swiftlint`)

If Node.js or Homebrew are not available, setup will skip those tools with a warning.

## Build Commands

### Building the App

```bash
make           # Build all targets (macOS, iOS, CLI) - default
make macos     # Build macOS app (Release mode)
make macos-dbg # Build macOS app (Debug mode)
make ios       # Build iOS app (Release mode)
make ios-dbg   # Build iOS app (Debug mode)
make clean     # Clean build artifacts
make help      # Show all available commands
```

### CLI Tool

Build and use the headless CLI tool:

```bash
make cli       # Build CLI tool
./build/mytree --vcf contacts.vcf --output tree.png  # Generate tree
make install   # Install CLI system-wide to /usr/local/bin
```

**CLI Options:**

- `--vcf <file>` - Input VCF file with contact data
- `--output <file>` - Output image file (PNG)
- `--root-name <name>` - Name of root contact
- `--degree <n>` - Degrees of separation to display
- `--headless` - Run in headless mode (automatically enabled with --vcf)

### Testing and Linting

```bash
make test          # Run all tests
make lint          # Run all linting (Swift + docs + links)
make lint-swift    # Run SwiftLint only
make lint-docs     # Lint markdown and spelling
make lint-markdown # Lint markdown files only
make lint-spelling # Check spelling only
make lint-links    # Check markdown links
```

### Code Coverage

```bash
make coverage           # Run tests with coverage
make coverage-check     # Check coverage against baseline
make coverage-commit    # Commit coverage reports to git
make coverage-report    # Generate detailed coverage report
```

**Coverage Requirements:**

- Minimum 50% line coverage
- No regressions allowed (>0.5% decrease fails CI)
- Coverage reports included in all CI runs

See **[Code Coverage Guide](CODE_COVERAGE.md)** for complete documentation.

### Development in Xcode

```bash
open MyTree.xcodeproj
```

Or use `make macos-dbg` for debug builds, then run from Xcode for full debugging support.

## Fastlane Automation

Fastlane provides a more streamlined way to build, test, and release. It's used in CI/CD and recommended for release management.

Fastlane is automatically installed by `make setup`. To view available automation:

```bash
# View available lanes
bundle exec fastlane lanes
```

### Fastlane Commands

#### Development

```bash
bundle exec fastlane lint              # Run all linting checks
bundle exec fastlane test              # Run tests with coverage
bundle exec fastlane build_macos       # Build macOS app (Release)
bundle exec fastlane build_macos_debug # Build macOS app (Debug)
bundle exec fastlane build_ios         # Build iOS app (Release)
bundle exec fastlane build_cli         # Build CLI tool
bundle exec fastlane clean             # Clean build artifacts
```

#### CI/CD

```bash
bundle exec fastlane ci                # Full CI pipeline (lint + test + build)
bundle exec fastlane build_all         # Build all release artifacts
```

#### Release Management

```bash
# Create DMG installer
bundle exec fastlane build_dmg version:1.0.0

# Prepare a complete release (test, build, tag)
bundle exec fastlane prepare_release version:1.0.0
```

### Make vs Fastlane

Both tools are available - use whichever fits your workflow:

| Task            | Make          | Fastlane                                              |
|-----------------|---------------|-------------------------------------------------------|
| Quick build     | `make macos`  | `bundle exec fastlane build_macos`                    |
| Run tests       | `make test`   | `bundle exec fastlane test`                           |
| Run linting     | `make lint`   | `bundle exec fastlane lint`                           |
| Full CI         | N/A           | `bundle exec fastlane ci`                             |
| Create release  | Manual        | `bundle exec fastlane prepare_release version:X.Y.Z`  |

**Recommendation:**

- **Local development**: Use `make` for speed and simplicity
- **CI/CD & releases**: Use `fastlane` for consistency and automation
- **Git hooks**: Already use `make` commands

## Project Structure

```text
MyTree/
├── MyTree/
│   ├── Models/          # Data models (FamilyMember, NodePosition, etc.)
│   ├── Services/        # Business logic (layout, contacts, relationships)
│   ├── Views/           # SwiftUI views and rendering
│   ├── ViewModels/      # MVVM state management
│   └── Utilities/       # Helpers and extensions
├── MyTreeIntegrationTests/  # Integration tests
├── MyTreeUnitTests/     # Unit tests
├── docs/                # Technical documentation (this directory)
├── test_vcf/            # Test VCF files for validation
└── scripts/             # Build and automation scripts
```

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and patterns for adding new functionality
- **[LAYOUT_ALGORITHM.md](LAYOUT_ALGORITHM.md)** - Detailed layout algorithm documentation
- **[CODE_COVERAGE.md](CODE_COVERAGE.md)** - Code coverage tracking and requirements
- **[../CONTRIBUTING.md](../CONTRIBUTING.md)** - Contribution guidelines and workflow

## Quick Reference

### Adding New Features

- **New view**: See [ARCHITECTURE.md → Adding a New View](ARCHITECTURE.md#adding-a-new-view)
- **New model**: See [ARCHITECTURE.md → Adding a New Model](ARCHITECTURE.md#adding-a-new-model)
- **New localizer**: See [ARCHITECTURE.md → Adding a New Localizer](ARCHITECTURE.md#adding-a-new-localizer)
- **Layout changes**: See [LAYOUT_ALGORITHM.md](LAYOUT_ALGORITHM.md)

### Configuration Files

MyTree uses JSON configuration files for easy customization:

- **Gender names**: `male_names.json` and `female_names.json` - Lists of names used for gender inference
- **Localizations**: `localizations/*.json` - Language-specific relationship labels

These files are automatically bundled with the app and can be edited
without code changes.

**Remote Configuration (Optional)**: MyTree supports **Firebase Remote Config**
for managing configurations remotely without app updates.
See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for setup instructions.

See [ARCHITECTURE.md → Configuration Files](ARCHITECTURE.md#configuration-files) for details.

### Code Style

- Follow SwiftLint rules (`.config/.swiftlint.yml`)
- Use MVVM pattern (state in ViewModel, not View)
- Keep models simple (data only, no logic)
- Use extensions for complex views (`View+Feature.swift`)
- Document public APIs with `///` comments
- Prefer `let` over `var` when possible

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](../CONTRIBUTING.md) for:

- Code of conduct
- Development workflow
- Commit message conventions
- Pull request process
- Coding standards

**Key Points:**

- Write tests for new functionality
- Maintain or improve code coverage (run `make coverage-check`)
- Follow conventional commit format (`feat:`, `fix:`, `docs:`, etc.)
- Run `make test` and `make lint` before committing
- Update documentation for architectural changes
- Git hooks will run automatically on commit

## Release Process

MyTree uses an automated release process via GitHub Actions with support for manual and tagged releases.

### Creating a Release

#### Option 1: Automated Release (Recommended)

Use Fastlane to prepare and tag a release:

```bash
# Prepare release (runs tests, builds artifacts, creates tag)
bundle exec fastlane prepare_release version:1.0.0

# Push the tag to trigger GitHub release
git push origin v1.0.0
```

This will:

1. Run all linting checks
2. Run all tests
3. Build all release artifacts (macOS, iOS, CLI, DMG)
4. Create a git tag `v1.0.0`
5. When pushed, GitHub Actions automatically creates the release

#### Option 2: Manual GitHub Release

Trigger a release manually via GitHub Actions:

1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Enter version number (e.g., `1.0.0`)
4. Choose whether to create a git tag
5. Mark as pre-release if needed
6. Run workflow

This builds all artifacts and creates the GitHub release.

#### Option 3: Direct Tag Push

Create and push a tag directly:

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

GitHub Actions will automatically build and create the release.

### Release Artifacts

Each release includes:

- **MyTree-{version}.dmg** - macOS installer (drag-and-drop)
- **mytree-macos-v{version}** - CLI tool binary
- **checksums.txt** - SHA256 checksums for verification

### Pre-release Versions

Mark versions as pre-release by including keywords:

- `v1.0.0-alpha` - Alpha release
- `v1.0.0-beta.1` - Beta release
- `v1.0.0-rc.1` - Release candidate

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **Major** (X.0.0) - Breaking changes
- **Minor** (0.X.0) - New features (backward compatible)
- **Patch** (0.0.X) - Bug fixes

### Release Checklist

Before creating a release:

- [ ] All tests passing (`make test` or `fastlane test`)
- [ ] Code coverage meets requirements (`make coverage-check`)
- [ ] All linting passing (`make lint` or `fastlane lint`)
- [ ] Update version in Info.plist (if applicable)
- [ ] Update CHANGELOG.md (if maintained)
- [ ] Review and merge all PRs for this release
- [ ] Clean working directory (`git status` shows no changes)

### CI/CD Workflows

#### CI Workflow (`.github/workflows/ci.yml`)

Runs on every push and pull request to `main` and `develop`:

- Linting (SwiftLint + Markdown + Spelling + Links)
- Tests with code coverage
- Coverage regression check (fails if coverage decreases)
- Build all targets (macOS, iOS, CLI)
- Create DMG
- Upload artifacts (retained for 7-30 days)

#### Release Workflow (`.github/workflows/release.yml`)

Runs on version tags (`v*`) or manual trigger:

- Validation (lint + test via Fastlane)
- Build all release artifacts
- Create GitHub release with binaries
- Generate release notes automatically
- Calculate checksums

### Local Release Testing

Test the release process locally:

```bash
# Build all artifacts
bundle exec fastlane build_all version:test

# Verify artifacts
ls -lh dist/          # DMG file
ls -lh build/cli/     # CLI tool
ls -lh build/Build/Products/Release/  # macOS app

# Test DMG installation
open dist/MyTree-test.dmg

# Test CLI tool
./build/cli/mytree --help
```

## Architecture Overview

**MVVM Pattern**: State managed in `FamilyTreeViewModel`, business logic in Services, views observe ViewModel

**Coordinate System**: Tree space (logical layout) vs Screen space (visual rendering with pan/zoom)

**Layout Algorithm**: Priority-based O(n log n) algorithm places close relatives first, ensuring balanced trees

**Animation**: Incremental placement with staggered node appearance and smooth connection rendering

See [ARCHITECTURE.md](ARCHITECTURE.md) for complete architectural details and design decisions.
