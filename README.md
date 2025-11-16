# MyTree - Family Tree Visualization

A macOS and iOS app that visualizes family relationships from your Contacts with beautiful animations.

## Features

- **Import from Contacts** - Automatically visualizes family relationships from macOS/iOS Contacts
- **Multi-language Support** - Relationship labels in English, Hindi, Spanish, and French
- **Smart Filtering** - View specific degrees of separation
- **CLI Tool** - Headless mode for batch processing and automation

## Quick Start

### Download Pre-built App

1. Go to the [Releases](https://github.com/jaingaurav/MyTree/releases) page
2. Download the latest `MyTree-*.dmg` file
3. Open the DMG and drag MyTree to your Applications folder
4. Right-click the app and select "Open" (first launch only)

### Build from Source

```bash
git clone https://github.com/jaingaurav/MyTree
cd MyTree
make setup  # One-time: Install dependencies (Fastlane, linting tools)
make        # Build all targets
```

See [Developer Documentation](docs/README.md) for detailed build instructions.

## Requirements

- **macOS 12.0+** (Monterey) or **iOS 15.0+**
- Xcode 14.0+ and Swift 5.7+ (for building from source)

## CLI Tool

The CLI tool enables headless rendering for automation and batch processing:

```bash
./build/mytree --vcf contacts.vcf --output tree.png
```

For installation and advanced usage, see [Developer Documentation](docs/README.md#build-commands).

## Documentation

- **[Developer Guide](docs/README.md)** - Build instructions, architecture, and development workflow
- **[Architecture](docs/ARCHITECTURE.md)** - System design and patterns
- **[Layout Algorithm](docs/LAYOUT_ALGORITHM.md)** - Detailed algorithm documentation
- **[Code Coverage](docs/CODE_COVERAGE.md)** - Coverage tracking and requirements

## Quality & Testing

MyTree maintains high code quality through:

- **Automated Testing** - Comprehensive unit and integration tests
- **Code Coverage** - Minimum 50% coverage with regression prevention
- **Continuous Integration** - Automated checks on every PR
- **Code Linting** - SwiftLint + markdown validation

See [Code Coverage Documentation](docs/CODE_COVERAGE.md) for details.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the [GNU Affero General Public License v3.0 (AGPLv3)](LICENSE).

**Summary:**

- ✅ **Open source** - Free to use, modify, and distribute
- ✅ **Commercial use allowed** - Can be used in commercial products
- ✅ **Strong copyleft** - Derivative works must also be AGPLv3
- ✅ **Network copyleft** - Source must be available even for network services
- 📋 **CLA required** - Contributors assign copyright to project maintainer

**Note:** By contributing to this project, you agree to assign copyright of your
contributions to Gaurav Jain. This enables dual-licensing and commercial licensing
arrangements similar to MongoDB's model.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full Contributor License Agreement.

For alternative licensing arrangements, contact `gaurav@gauravjain.org`
