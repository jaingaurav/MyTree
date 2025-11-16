# Configuration Files

This directory contains all linter and tool configuration files for the MyTree project.

## Files

### Code Quality Tools

- **`.swiftlint.yml`** - SwiftLint configuration for Swift code style enforcement
- **`cspell.json`** - CSpell configuration for spell checking code and documentation
- **`.markdownlint-cli2.yaml`** - Markdownlint configuration for markdown file formatting
- **`.markdown-link-check.json`** - Configuration for checking markdown link validity

## Symlinks

For tool auto-discovery, these config files are symlinked from the project root:

```bash
.swiftlint.yml -> .config/.swiftlint.yml
cspell.json -> .config/cspell.json
.markdownlint-cli2.yaml -> .config/.markdownlint-cli2.yaml
.markdown-link-check.json -> .config/.markdown-link-check.json
```

This allows tools to automatically discover their configuration files while keeping
the actual config files organized in the `.config/` directory.

## Usage

These configuration files are automatically used by:

- `make lint` - Runs all linters
- `make lint-swift` - SwiftLint
- `make lint-spelling` - CSpell
- `make lint-markdown` - Markdownlint
- `make lint-links` - Markdown link checker

See the [Makefile](../Makefile) for more details.

## Modifying Configurations

To modify any configuration:

1. Edit the file in `.config/` directory
2. Changes take effect immediately (symlinks ensure tools find the updated config)
3. Run `make lint` to verify changes

## Why `.config/`?

Config files are organized in `.config/` to:

- Keep the project root clean
- Group related configuration files together
- Maintain tool auto-discovery via symlinks
- Follow modern project organization practices
