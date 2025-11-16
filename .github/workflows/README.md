# GitHub Actions CI/CD Workflows

This directory contains automated workflows for building, testing, and releasing MyTree.

## Workflows

### `ci.yml` - Continuous Integration & Release

Automatically runs on:

- Pushes to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Git tags starting with `v` (e.g., `v1.0.0`)
- Manual trigger via GitHub Actions UI

## Jobs Overview

### 1. **CLA Assistant** 📝

- Ensures all contributors have signed the Contributor License Agreement
- Automatically comments on pull requests
- Stores signatures in `signatures/cla.json`
- See [CONTRIBUTING.md](../../CONTRIBUTING.md) for CLA details
- **Required for all pull requests**

### 2. **SwiftLint** 🔍

- Enforces code style and quality
- Runs SwiftLint in strict mode
- Must pass before builds proceed

### 3. **Tests** 🧪

- Runs all unit and integration tests
- Uploads test results for review
- **Required status check** - must pass to merge PRs
- Required for all builds

### 4. **Coverage Check** 📊

- Checks code coverage against base branch
- Ensures coverage doesn't decrease
- Enforces minimum coverage threshold (50%)
- **Required status check** - must pass to merge PRs
- Runs after tests complete
- Commits coverage reports automatically

### 5. **Build Jobs** 🔨

Builds all targets in Release configuration:

| Job | Output | Artifact Name |
| ----- | -------- | --------------- |
| **build-macos** | macOS .app bundle | `MyTree-macOS-Release` |
| **build-ios** | iOS build | `MyTree-iOS-Release` |
| **build-cli** | Standalone CLI binary | `mytree-cli-Release` |
| **create-dmg** | DMG installer | `MyTree-macOS-DMG` |

### 6. **DMG Creation** 📦

Creates a professional DMG installer with:

- Custom window size and icon positioning
- Applications folder link for easy installation
- Version-tagged filename (e.g., `MyTree-v1.0.0.dmg`)
- Compressed format for smaller downloads

**Features:**

- Uses `create-dmg` for polished installer experience
- Falls back to `hdiutil` if needed
- Includes app icon and drag-to-install UI
- Retained for 30 days (vs. 7 days for other artifacts)

### 7. **GitHub Release** 🚀

**Triggered by:** Git tags starting with `v` (e.g., `v1.0.0`, `v2.1.3-beta`)

Automatically creates a GitHub release with:

- **DMG installer** for end users
- **CLI tool** with version-tagged name
- Auto-generated release notes
- Installation instructions
- Security warnings for non-notarized apps

## Setup Requirements

### CLA Assistant Setup

The CLA Assistant workflow requires a Personal Access Token to store signatures:

1. **Create a Personal Access Token:**
   - Go to GitHub Settings > Developer settings > Personal access tokens > Fine-grained tokens
   - Click "Generate new token"
   - Name it "CLA Assistant"
   - Set expiration as needed
   - Repository access: Select your repository
   - Permissions: Grant `Contents` (Read and Write)

2. **Add Token as Secret:**
   - Go to your repository Settings > Secrets and variables > Actions
   - Click "New repository secret"
   - Name: `PERSONAL_ACCESS_TOKEN`
   - Value: Paste your token
   - Click "Add secret"

The workflow will now be able to commit CLA signatures to `signatures/cla.json`.

## Using the Workflows

### For Development Builds

Every push to `main` or `develop` triggers a full build:

```bash
git push origin main
```

Then download artifacts from the Actions tab in GitHub.

### Creating a Release

1. **Tag your commit:**

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Automatic Release Creation:**
   - GitHub Actions builds all targets
   - Creates a DMG installer
   - Publishes a GitHub Release
   - Attaches DMG and CLI tool as downloadable assets

3. **Download from Releases:**
   - Navigate to your repository's Releases page
   - Download `MyTree-v1.0.0.dmg` for the app
   - Download `mytree-macos-v1.0.0` for the CLI

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- `v1.0.0` - Major release
- `v1.1.0` - Minor update (new features)
- `v1.0.1` - Patch (bug fixes)
- `v1.0.0-beta.1` - Pre-release (marked as prerelease in GitHub)
- `v1.0.0-rc.1` - Release candidate (marked as prerelease)

### Manual Workflow Trigger

You can manually run the workflow from GitHub:

1. Go to **Actions** tab
2. Select **CI** workflow
3. Click **Run workflow**
4. Choose branch and run

## Artifacts

### Artifact Retention

- **DMG files**: 30 days
- **Other artifacts**: 7 days

### Downloading Artifacts

From workflow runs:

1. Go to **Actions** tab
2. Click on a workflow run
3. Scroll to **Artifacts** section
4. Download desired artifact

From releases (tags only):

1. Go to **Releases** page
2. Download assets from the latest release

## DMG Features

The generated DMG provides a professional installation experience:

```text
┌─────────────────────────────────────┐
│  MyTree                             │
│  ┌─────────┐        ┌─────────┐    │
│  │         │   →    │  📁     │    │
│  │ MyTree  │        │ Apps    │    │
│  │  .app   │        │         │    │
│  └─────────┘        └─────────┘    │
└─────────────────────────────────────┘
```

- Custom background and layout
- Drag-and-drop to Applications
- Compressed for fast download
- Version in filename for easy identification

## Troubleshooting

### Build Failures

**SwiftLint errors:**

- Run `swiftlint lint --strict` locally
- Fix violations before pushing

**Test failures:**

- Run `make test` locally
- Check test logs in the Actions tab

**DMG creation fails:**

- Workflow automatically falls back to `hdiutil`
- Check that app icon exists at expected path

### Release Issues

**Release not created:**

- Ensure tag starts with `v` (e.g., `v1.0.0`, not `1.0.0`)
- Check workflow permissions in Settings > Actions

**Assets not attached:**

- Verify artifacts were created in previous jobs
- Check workflow logs for download errors

## Local Testing

You can replicate the CI process locally:

```bash
# Lint
swiftlint lint --strict

# Test
make test

# Build all targets
make all

# Create CLI tool
make cli

# Create DMG (requires create-dmg)
brew install create-dmg
create-dmg --volname "MyTree" \
  --app-drop-link 600 185 \
  MyTree.dmg build/Build/Products/Release/MyTree.app
```

## Security Notes

### Code Signing

The workflow creates **unsigned** builds suitable for:

- Personal use
- Testing and development
- Internal distribution

For App Store or notarized distribution, you need:

- Apple Developer account ($99/year)
- Code signing certificates
- Notarization workflow

### Gatekeeper

Users downloading the DMG will see a security warning because:

- The app is not notarized by Apple
- This is expected for open-source builds

**Users can bypass this:**

1. Right-click the app
2. Select "Open"
3. Click "Open" in the dialog

## Future Enhancements

Possible improvements:

- [ ] Add code signing with secrets
- [ ] Notarization workflow for Gatekeeper
- [ ] Universal binary (Intel + Apple Silicon)
- [ ] Automated TestFlight uploads for iOS
- [ ] Performance benchmarking
- [ ] Code coverage reports

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [create-dmg Tool](https://github.com/create-dmg/create-dmg)
- [Xcode Build Settings](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Semantic Versioning](https://semver.org/)
