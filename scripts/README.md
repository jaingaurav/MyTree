# Coverage Scripts

This directory contains scripts for managing code coverage.

## Active Scripts

### `check-coverage.sh`

**Purpose**: Main coverage check script
**Usage**: `./scripts/check-coverage.sh <xcresult-path>`
**Status**: ✅ Active - Used by `make coverage-check` and CI

Checks overall coverage against minimum threshold and base branch.

### `check-coverage-git.sh`

**Purpose**: Git-based coverage comparison
**Usage**: Called by `check-coverage.sh`
**Status**: ✅ Active - Compares coverage against base branch

Fetches coverage data from GitHub Actions artifacts (or git history as fallback) and compares.

### `check-file-coverage.sh`

**Purpose**: File-level coverage regression detection
**Usage**: Called by `check-coverage.sh`
**Status**: ✅ Active - Prevents file-level coverage regressions

Ensures individual files don't decrease in coverage even if overall coverage increases.

### `store-coverage-github.sh`

**Purpose**: Store coverage data for GitHub Actions artifacts
**Usage**: `./scripts/store-coverage-github.sh <xcresult-path> [commit-sha]`
**Status**: ✅ Active - CI only (automatically detects CI environment)

Stores coverage data locally for GitHub Actions to upload as artifacts. Only works in CI.

### `fetch-coverage-github.sh`

**Purpose**: Fetch coverage data from GitHub API/artifacts
**Usage**: `./scripts/fetch-coverage-github.sh <commit-sha> [base-branch]`
**Status**: ✅ Active - Used by `check-coverage-git.sh`

Fetches historical coverage data from GitHub Actions artifacts or git history.

## Pre-commit Hook

### `pre-commit`

**Purpose**: Git pre-commit hook
**Status**: ✅ Active - Runs before commits

Performs linting and other checks before allowing commits.
