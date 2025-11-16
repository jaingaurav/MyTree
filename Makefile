.PHONY: help macos macos-dbg ios ios-dbg cli test coverage coverage-check coverage-commit coverage-report lint lint-swift lint-docs lint-markdown lint-markdown-fix lint-whitespace lint-whitespace-fix lint-spelling lint-links clean install setup all release debug

# Configuration
PROJECT = MyTree.xcodeproj
SCHEME = MyTree
BUILD_DIR = ./build
RELEASE_APP = $(BUILD_DIR)/Build/Products/Release/MyTree.app
DEBUG_APP = $(BUILD_DIR)/Build/Products/Debug/MyTree.app
RELEASE_BINARY = $(RELEASE_APP)/Contents/MacOS/MyTree
DEBUG_BINARY = $(DEBUG_APP)/Contents/MacOS/MyTree
CLI_BINARY = $(BUILD_DIR)/mytree
INSTALL_PREFIX ?= /usr/local
INSTALL_BIN := $(INSTALL_PREFIX)/bin

# Default target
.DEFAULT_GOAL := all

# Help target
help:
	@echo "MyTree Makefile"
	@echo ""
	@echo "Build Targets (using Xcode):"
	@echo "  all                - Build all targets (default)"
	@echo "  macos              - Build macOS app (optimized)"
	@echo "  macos-dbg          - Build macOS app (debug mode)"
	@echo "  ios                - Build iOS app (optimized)"
	@echo "  ios-dbg            - Build iOS app (debug mode)"
	@echo "  cli                - Build CLI tool"
	@echo "  release            - Build signed release versions of all targets"
	@echo ""
	@echo "Test & Coverage Targets:"
	@echo "  test               - Run all tests"
	@echo "  coverage           - Run tests with code coverage"
	@echo "  coverage-check     - Check coverage against base branch"
	@echo "  coverage-commit    - Commit coverage reports (main branch)"
	@echo "  coverage-report    - Display coverage report"
	@echo ""
	@echo "Lint Targets:"
	@echo "  lint               - Run all linting (Swift + docs + links)"
	@echo "  lint-swift         - Run SwiftLint"
	@echo "  lint-docs          - Lint documentation (markdown + spelling)"
	@echo "  lint-markdown      - Lint and auto-fix markdown files"
	@echo "  lint-markdown-fix  - Auto-fix markdown files only"
	@echo "  lint-whitespace    - Check for trailing whitespace"
	@echo "  lint-whitespace-fix - Auto-fix trailing whitespace"
	@echo "  lint-spelling      - Check spelling only"
	@echo "  lint-links         - Check markdown links"
	@echo ""
	@echo "Utility Targets:"
	@echo "  install            - Install CLI tool to $(INSTALL_BIN)"
	@echo "  clean              - Clean all build artifacts and derived data"
	@echo "  setup              - Set up dev environment (Fastlane, linting tools, git hooks)"
	@echo "  help               - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make                              # Build all targets (default)"
	@echo "  make release                      # Build signed release versions"
	@echo "  make macos                        # Build macOS app only"
	@echo "  make cli && make install          # Build and install CLI"
	@echo "  make coverage                     # Run tests with coverage"
	@echo "  make coverage-check               # Check coverage against base branch"
	@echo "  make coverage-commit              # Commit coverage reports (main branch)"
	@echo ""
	@echo "After building CLI:"
	@echo "  $(CLI_BINARY) --headless --vcf contacts.vcf --output tree.png"

# Build macOS app (optimized)
macos:
	@echo "Building macOS app (Release mode)..."
	@xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build
	@if [ -f $(RELEASE_BINARY) ]; then \
		echo ""; \
		echo "✅ Build successful!"; \
		echo "App location: $(RELEASE_APP)"; \
	else \
		echo "❌ Build failed"; \
		exit 1; \
	fi

# Build macOS app (debug)
macos-dbg:
	@echo "Building macOS app (Debug mode)..."
	@xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		build
	@if [ -f $(DEBUG_BINARY) ]; then \
		echo ""; \
		echo "✅ Build successful!"; \
		echo "App location: $(DEBUG_APP)"; \
	else \
		echo "❌ Build failed"; \
		exit 1; \
	fi

# Build iOS app (optimized)
ios:
	@echo "Building iOS app (Release mode)..."
	@xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-sdk iphoneos \
		-derivedDataPath $(BUILD_DIR) \
		build
	@echo "✅ iOS build complete"

# Build iOS app (debug)
ios-dbg:
	@echo "Building iOS app (Debug mode)..."
	@xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-sdk iphoneos \
		-derivedDataPath $(BUILD_DIR) \
		build
	@echo "✅ iOS build complete"

# Build CLI tool
cli: macos
	@echo "Creating standalone CLI tool..."
	@mkdir -p $(BUILD_DIR)
	@cp $(RELEASE_BINARY) $(CLI_BINARY)
	@chmod +x $(CLI_BINARY)
	@echo "Removing code signature and entitlements..."
	@codesign --remove-signature $(CLI_BINARY) 2>/dev/null || true
	@echo "Re-signing without entitlements..."
	@codesign --force --sign - $(CLI_BINARY) 2>/dev/null || true
	@echo ""
	@echo "✅ CLI tool built!"
	@echo "Binary location: $(CLI_BINARY)"
	@echo ""
	@echo "Usage:"
	@echo "  $(CLI_BINARY) --headless --vcf contacts.vcf --output tree.png"

# Build all targets (optimized)
all: macos ios cli
	@echo ""
	@echo "✅ All targets built successfully!"

# Run tests
test:
	@echo "Running integration tests..."
	@xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-only-testing:MyTreeIntegrationTests \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO
	@echo ""
	@echo "Running unit tests..."
	@xcodebuild test \
		-project $(PROJECT) \
		-scheme MyTreeUnitTests \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# Run tests with code coverage
coverage:
	@rm -rf $(BUILD_DIR)/IntegrationTestResults.xcresult $(BUILD_DIR)/UnitTestResults.xcresult $(BUILD_DIR)/TestResults.xcresult
	@xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-only-testing:MyTreeIntegrationTests \
		-derivedDataPath $(BUILD_DIR) \
		-enableCodeCoverage YES \
		-resultBundlePath $(BUILD_DIR)/IntegrationTestResults.xcresult \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO > /dev/null
	@xcodebuild test \
		-project $(PROJECT) \
		-scheme MyTreeUnitTests \
		-derivedDataPath $(BUILD_DIR) \
		-enableCodeCoverage YES \
		-resultBundlePath $(BUILD_DIR)/UnitTestResults.xcresult \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO > /dev/null
	@COV=$$(xcrun xccov view --report --json $(BUILD_DIR)/UnitTestResults.xcresult 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"{d.get('lineCoverage',0)*100:.1f}%\")" 2>/dev/null || echo "N/A"); \
	echo "✅ Coverage: $$COV"

# Check coverage against base branch
coverage-check: coverage
	@./scripts/check-coverage.sh $(BUILD_DIR)/UnitTestResults.xcresult

# Store coverage data (uses GitHub Actions artifacts, not git commits)
coverage-commit: coverage
	@echo "⚠️  Coverage data is now stored in GitHub Actions artifacts, not git"
	@echo "   Run 'make coverage' in CI to store coverage data automatically"
	@echo "   Coverage data is retained for 365 days as GitHub Actions artifacts"

# Display coverage report
coverage-report:
	@if [ -d "$(BUILD_DIR)/UnitTestResults.xcresult" ]; then \
		echo "=== Unit Tests ==="; \
		xcrun xccov view --report $(BUILD_DIR)/UnitTestResults.xcresult; \
	fi
	@if [ -d "$(BUILD_DIR)/IntegrationTestResults.xcresult" ]; then \
		echo ""; echo "=== Integration Tests ==="; \
		xcrun xccov view --report $(BUILD_DIR)/IntegrationTestResults.xcresult; \
	fi

# Linting targets

# Run all linting
lint: lint-swift lint-whitespace lint-docs lint-links
	@echo ""
	@echo "✅ All linting passed!"

# Lint Swift code
lint-swift:
	@echo "📝 Running SwiftLint..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --quiet; \
		echo "✅ SwiftLint passed"; \
	else \
		echo "⚠️  SwiftLint not found. Install with: brew install swiftlint"; \
		exit 1; \
	fi

# Lint documentation (markdown + spelling)
lint-docs: lint-markdown lint-spelling
	@echo "✅ Documentation linting passed!"

# Lint markdown files
lint-markdown:
	@echo "🔍 Checking markdown style..."
	@if command -v markdownlint-cli2 >/dev/null 2>&1; then \
		markdownlint-cli2 --fix "**/*.md" "#build" "#.build" && echo "✅ Markdown style check passed"; \
	else \
		echo "⚠️  markdownlint-cli2 not found. Install with:"; \
		echo "   npm install -g markdownlint-cli2"; \
		exit 1; \
	fi

# Auto-fix markdown files
lint-markdown-fix:
	@echo "🔧 Auto-fixing markdown style issues..."
	@if command -v markdownlint-cli2 >/dev/null 2>&1; then \
		markdownlint-cli2 --fix "**/*.md" "#build" "#.build" && echo "✅ Markdown files auto-fixed"; \
	else \
		echo "⚠️  markdownlint-cli2 not found. Install with:"; \
		echo "   npm install -g markdownlint-cli2"; \
		exit 1; \
	fi

# Check spelling
lint-spelling:
	@echo "🔍 Checking spelling..."
	@if command -v cspell >/dev/null 2>&1; then \
		cspell lint "**/*.md" "**/*.swift" --no-progress --quiet && echo "✅ Spell check passed"; \
	else \
		echo "⚠️  cspell not found. Install with:"; \
		echo "   npm install -g cspell"; \
		exit 1; \
	fi

# Check for trailing whitespace (ignoring "new blank line at EOF" which is actually good practice)
lint-whitespace:
	@echo "🔍 Checking for trailing whitespace..."
	@if git rev-parse --git-dir > /dev/null 2>&1; then \
		ISSUES=0; \
		echo "Checking staged files..."; \
		STAGED_ISSUES=$$(git diff --cached --check --diff-filter=ACMR 2>&1 | grep -v "new blank line at EOF" | grep -q . && echo "1" || echo "0"); \
		if [ $$STAGED_ISSUES -eq 1 ]; then \
			echo "❌ Trailing whitespace issues in staged files:"; \
			git diff --cached --check --diff-filter=ACMR 2>&1 | grep -v "new blank line at EOF" | head -20; \
			ISSUES=1; \
		fi; \
		echo "Checking working directory files..."; \
		WD_ISSUES=$$(git diff --check --diff-filter=ACMR 2>&1 | grep -v "new blank line at EOF" | grep -q . && echo "1" || echo "0"); \
		if [ $$WD_ISSUES -eq 1 ]; then \
			echo "❌ Trailing whitespace issues in working directory:"; \
			git diff --check --diff-filter=ACMR 2>&1 | grep -v "new blank line at EOF" | head -20; \
			ISSUES=1; \
		fi; \
		if [ $$ISSUES -eq 1 ]; then \
			echo ""; \
			echo "   Run 'make lint-whitespace-fix' to auto-fix these issues."; \
			exit 1; \
		else \
			echo "✅ No trailing whitespace issues found"; \
		fi; \
	else \
		echo "⚠️  Not a git repository. Skipping whitespace check."; \
	fi

# Auto-fix trailing whitespace (only fixes actual trailing whitespace, not blank lines at EOF)
lint-whitespace-fix:
	@echo "🔧 Auto-fixing trailing whitespace..."
	@if git rev-parse --git-dir > /dev/null 2>&1; then \
		FIXED=0; \
		git diff --cached --check --diff-filter=ACMR 2>&1 | grep "trailing whitespace" | \
		while IFS=: read -r file line rest; do \
			if [ -f "$$file" ]; then \
				sed -i '' -e 's/[[:space:]]*$$//' "$$file"; \
				echo "Fixed trailing whitespace: $$file"; \
				FIXED=1; \
			fi; \
		done; \
		git diff --check --diff-filter=ACMR 2>&1 | grep "trailing whitespace" | \
		while IFS=: read -r file line rest; do \
			if [ -f "$$file" ]; then \
				sed -i '' -e 's/[[:space:]]*$$//' "$$file"; \
				echo "Fixed trailing whitespace: $$file"; \
				FIXED=1; \
			fi; \
		done; \
		if [ $$FIXED -eq 1 ]; then \
			echo "✅ Trailing whitespace fixes applied. Please review and stage the changes."; \
		else \
			echo "✅ No trailing whitespace issues to fix"; \
		fi; \
	else \
		echo "⚠️  Not a git repository. Cannot auto-fix."; \
		exit 1; \
	fi

# Check markdown links
lint-links:
	@echo "🔗 Checking markdown links..."
	@if command -v markdown-link-check >/dev/null 2>&1; then \
		set -e; \
		TEMP_FILE=$$(mktemp); \
		find . -name "*.md" -not -path "./build/*" -not -path "./.build/*" -not -path "./.*" -not -path "./fastlane/README.md" | \
		while read -r file; do \
			if ! markdown-link-check --quiet "$$file"; then \
				echo "1" > "$$TEMP_FILE"; \
			fi; \
		done; \
		if [ -f "$$TEMP_FILE" ] && [ "$$(cat $$TEMP_FILE 2>/dev/null)" = "1" ]; then \
			rm -f "$$TEMP_FILE"; \
			echo "❌ Link check failed - dead links found"; \
			exit 1; \
		else \
			rm -f "$$TEMP_FILE"; \
			echo "✅ Link check passed"; \
		fi; \
	else \
		echo "⚠️  markdown-link-check not found. Install with:"; \
		echo "   npm install -g markdown-link-check"; \
		exit 1; \
	fi

# Install CLI tool to system PATH
install: cli
	@echo "Installing CLI tool to $(INSTALL_BIN)..."
	@sudo mkdir -p $(INSTALL_BIN)
	@sudo cp $(CLI_BINARY) $(INSTALL_BIN)/mytree
	@sudo chmod +x $(INSTALL_BIN)/mytree
	@echo "✅ CLI tool installed to $(INSTALL_BIN)/mytree"
	@echo ""
	@echo "You can now run: mytree --headless --vcf contacts.vcf --output tree.png"

# Clean all build artifacts and derived data
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "Cleaning Xcode derived data..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/MyTree-*
	@echo "✅ Clean complete"

# Set up development environment
setup:
	@echo "🔧 Setting up development environment..."
	@echo ""

	@echo "📦 Checking Ruby and Bundler..."
	@if ! command -v ruby >/dev/null 2>&1; then \
		echo "❌ Ruby not found. Please install Ruby 2.7+"; \
		echo "   macOS: Ruby is pre-installed"; \
		echo "   Or: brew install ruby"; \
		exit 1; \
	fi
	@echo "   ✓ Ruby $(shell ruby --version | cut -d' ' -f2)"
	@if ! command -v bundle >/dev/null 2>&1; then \
		echo "   Installing Bundler..."; \
		gem install bundler; \
	fi
	@echo "   ✓ Bundler installed"
	@echo ""

	@echo "💎 Installing Fastlane and Ruby dependencies..."
	@bundle install
	@echo "   ✓ Fastlane installed"
	@echo ""

	@echo "📝 Installing linting tools..."
	@if ! command -v npm >/dev/null 2>&1; then \
		echo "   ⚠️  npm not found. Skipping npm linting tools."; \
		echo "      Install Node.js to enable markdown linting: brew install node"; \
	else \
		echo "   Installing markdown linting tools..."; \
		npm install -g markdownlint-cli2 cspell markdown-link-check 2>/dev/null || \
		echo "   ⚠️  Could not install npm tools globally. You may need sudo or install locally."; \
	fi
	@if ! command -v swiftlint >/dev/null 2>&1; then \
		echo "   Installing SwiftLint..."; \
		if command -v brew >/dev/null 2>&1; then \
			brew install swiftlint; \
		else \
			echo "   ⚠️  Homebrew not found. Please install SwiftLint manually:"; \
			echo "      https://github.com/realm/SwiftLint#installation"; \
		fi \
	else \
		echo "   ✓ SwiftLint already installed"; \
	fi
	@echo ""

	@echo "🪝 Installing git hooks..."
	@mkdir -p .git/hooks
	@ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "   ✓ Git hooks installed"
	@echo ""
	@echo "✅ Setup complete!"

# Build signed release versions of all targets
release: clean
	@echo "🚀 Building signed release versions..."
	@echo ""
	@echo "📦 Building macOS app (signed)..."
	@xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build
	@echo ""
	@echo "📱 Building iOS app (signed)..."
	@xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-sdk iphoneos \
		-derivedDataPath $(BUILD_DIR) \
		build
	@echo ""
	@echo "🔧 Creating CLI tool..."
	@mkdir -p $(BUILD_DIR)/cli
	@cp $(RELEASE_BINARY) $(BUILD_DIR)/cli/mytree
	@chmod +x $(BUILD_DIR)/cli/mytree
	@codesign --remove-signature $(BUILD_DIR)/cli/mytree 2>/dev/null || true
	@codesign --force --sign - $(BUILD_DIR)/cli/mytree 2>/dev/null || true
	@echo ""
	@echo "✅ Release build complete!"
	@echo ""
	@echo "📦 Artifacts:"
	@echo "  macOS app: $(RELEASE_APP)"
	@echo "  iOS app:   $(BUILD_DIR)/Build/Products/Release-iphoneos/$(SCHEME).app"
	@echo "  CLI tool:  $(BUILD_DIR)/cli/mytree"
	@echo ""
	@echo "💡 Next steps:"
	@echo "  - Create DMG: See .github/workflows/ci.yml create-dmg job"
	@echo "  - Install CLI: make install"
