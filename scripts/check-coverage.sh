#!/bin/bash
#
# check-coverage.sh
#
# Script to extract code coverage from Xcode test results and check for regression.
# This ensures that code coverage does not decrease with new changes.
#
# This script tries git-based comparison first (comparing against base branch),
# then falls back to baseline file comparison if git comparison is not available.
#
# Usage:
#   ./scripts/check-coverage.sh <xcresult-path> [baseline-file]
#
# Arguments:
#   xcresult-path  - Path to .xcresult bundle from xcodebuild test
#   baseline-file  - (Deprecated) Not used - git-based comparison is required
#
# Exit Codes:
#   0 - Coverage is acceptable (meets or exceeds baseline/base branch)
#   1 - Coverage regression detected or error occurred
#

set -euo pipefail

# Configuration
XCRESULT_PATH="${1:-}"
# Baseline file is deprecated - git-based comparison is required
BASELINE_FILE="${2:-}"
COVERAGE_REPORT_DIR="./coverage-reports"
MIN_COVERAGE_THRESHOLD=50.0  # Minimum acceptable coverage percentage
USE_GIT_COMPARISON=true  # Try git-based comparison first

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

usage() {
    echo "Usage: $0 <xcresult-path> [baseline-file]"
    echo ""
    echo "Arguments:"
    echo "  xcresult-path  - Path to .xcresult bundle from xcodebuild test"
    echo "  baseline-file  - (Deprecated) Not used"
    exit 1
}

# Validate arguments
if [ -z "$XCRESULT_PATH" ]; then
    log_error "Missing required argument: xcresult-path"
    usage
fi

if [ ! -d "$XCRESULT_PATH" ]; then
    log_error "xcresult bundle not found: $XCRESULT_PATH"
    exit 1
fi

# Check if xcrun is available
if ! command -v xcrun &> /dev/null; then
    log_error "xcrun not found. This script requires Xcode Command Line Tools."
    exit 1
fi

log_info "Extracting code coverage from: $XCRESULT_PATH"

# Create coverage report directory
mkdir -p "$COVERAGE_REPORT_DIR"

# Extract coverage data using xcrun
COVERAGE_JSON="$COVERAGE_REPORT_DIR/coverage-$(date +%Y%m%d-%H%M%S).json"
xcrun xccov view --report --json "$XCRESULT_PATH" > "$COVERAGE_JSON"

log_success "Coverage data extracted to: $COVERAGE_JSON"

# Parse coverage percentage
CURRENT_COVERAGE=$(python3 -c "
import json
import sys

try:
    with open('$COVERAGE_JSON', 'r') as f:
        data = json.load(f)

    # Extract line coverage percentage
    coverage = data.get('lineCoverage', 0) * 100
    print(f'{coverage:.2f}')
except Exception as e:
    print('0.00', file=sys.stderr)
    sys.exit(1)
")

if [ $? -ne 0 ]; then
    log_error "Failed to parse coverage data"
    exit 1
fi

log_info "Current coverage: ${CURRENT_COVERAGE}%"

# Check against minimum threshold
if (( $(echo "$CURRENT_COVERAGE < $MIN_COVERAGE_THRESHOLD" | bc -l) )); then
    log_error "Coverage ${CURRENT_COVERAGE}% is below minimum threshold of ${MIN_COVERAGE_THRESHOLD}%"
    exit 1
fi

log_success "Coverage meets minimum threshold of ${MIN_COVERAGE_THRESHOLD}%"

# Use git-based comparison (required for PRs)
COMPARISON_METHOD=""

if [ "$USE_GIT_COMPARISON" = "true" ] && git rev-parse --git-dir > /dev/null 2>&1; then
    # Use git-based comparison
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/check-coverage-git.sh" ]; then
        log_info "Using git-based coverage comparison..."

        # Determine base branch (main for PRs, or current branch if on main)
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
            BASE_BRANCH="main"
        else
            # Try to detect base branch from PR or use main as default
            BASE_BRANCH="main"
        fi

        # Run git-based comparison - this will fail if no coverage data is found
        if bash "$SCRIPT_DIR/check-coverage-git.sh" "$XCRESULT_PATH" "$BASE_BRANCH"; then
            COMPARISON_METHOD="git"
            # The git script handles its own comparison, so we can exit here if successful
            exit 0
        else
            log_error "Git-based coverage comparison failed!"
            log_error ""
            log_error "This usually means coverage reports are not committed to git."
            log_error "For PRs, GitHub Actions should automatically commit coverage reports."
            log_error ""
            log_error "To fix:"
            log_error "  1. Ensure coverage reports are committed to the base branch"
            log_error "  2. Run: make coverage && make coverage-commit"
            log_error "  3. Or check CI logs to see if coverage reports were committed"
            exit 1
        fi
    else
        log_error "Git-based coverage comparison script not found: $SCRIPT_DIR/check-coverage-git.sh"
        exit 1
    fi
else
    log_error "Git repository not found. Coverage comparison requires git."
    log_error "Please run this in a git repository with coverage reports committed."
    exit 1
fi

# Generate human-readable report
log_info "Generating coverage report..."

COVERAGE_TXT="$COVERAGE_REPORT_DIR/coverage-report.txt"
xcrun xccov view --report "$XCRESULT_PATH" > "$COVERAGE_TXT"

log_success "Coverage report saved to: $COVERAGE_TXT"

# Display summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "           Code Coverage Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Coverage:     ${CURRENT_COVERAGE}%"
echo "  Threshold:    ${MIN_COVERAGE_THRESHOLD}%"
echo "  Method:       git-based comparison"
echo ""
echo "  Report:       $COVERAGE_TXT"
echo "  Raw Data:     $COVERAGE_JSON"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_success "Coverage check passed!"

# Also check file-level coverage
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/check-file-coverage.sh" ]; then
    log_info "Checking file-level coverage..."
    if bash "$SCRIPT_DIR/check-file-coverage.sh" "$XCRESULT_PATH" "$BASE_BRANCH" 2>/dev/null; then
        log_success "File-level coverage check passed"
    else
        log_error "File-level coverage check failed"
        exit 1
    fi
fi

exit 0
