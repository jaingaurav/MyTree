#!/bin/bash
#
# check-coverage-git.sh
#
# Script to extract code coverage from Xcode test results and compare against
# the base branch (main/develop) instead of a static baseline file.
# This ensures that code coverage does not decrease with new changes.
#
# Usage:
#   ./scripts/check-coverage-git.sh <xcresult-path> [base-branch]
#
# Arguments:
#   xcresult-path  - Path to .xcresult bundle from xcodebuild test
#   base-branch    - (Optional) Base branch to compare against (default: main)
#
# Exit Codes:
#   0 - Coverage is acceptable (meets or exceeds base branch)
#   1 - Coverage regression detected or error occurred
#

set -euo pipefail

# Configuration
XCRESULT_PATH="${1:-}"
BASE_BRANCH="${2:-main}"
COVERAGE_REPORT_DIR="./coverage-reports"
MIN_COVERAGE_THRESHOLD=50.0  # Minimum acceptable coverage percentage
TOLERANCE=0.5  # Tolerance for coverage comparison (percentage points)

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
    echo "Usage: $0 <xcresult-path> [base-branch]"
    echo ""
    echo "Arguments:"
    echo "  xcresult-path  - Path to .xcresult bundle from xcodebuild test"
    echo "  base-branch    - (Optional) Base branch to compare against (default: main)"
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

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not a git repository. Cannot compare against base branch."
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

# Extract current coverage data using xcrun
CURRENT_COVERAGE_JSON="$COVERAGE_REPORT_DIR/coverage-current-$(date +%Y%m%d-%H%M%S).json"
xcrun xccov view --report --json "$XCRESULT_PATH" > "$CURRENT_COVERAGE_JSON"

log_success "Coverage data extracted to: $CURRENT_COVERAGE_JSON"

# Parse current coverage percentage
CURRENT_COVERAGE=$(python3 -c "
import json
import sys

try:
    with open('$CURRENT_COVERAGE_JSON', 'r') as f:
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

# Try to get base branch coverage
BASE_COVERAGE=""
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

log_info "Current branch: $CURRENT_BRANCH"
log_info "Comparing against base branch: $BASE_BRANCH"

# Check if base branch exists
if ! git rev-parse --verify "origin/$BASE_BRANCH" > /dev/null 2>&1 && \
   ! git rev-parse --verify "$BASE_BRANCH" > /dev/null 2>&1; then
    log_error "Base branch '$BASE_BRANCH' not found locally or remotely"
    log_error ""
    log_error "Coverage comparison requires the base branch to exist."
    log_error "For PRs, ensure the base branch (main/develop) exists and has coverage reports."
    log_error ""
    log_error "To fix:"
    log_error "  1. Fetch the base branch: git fetch origin $BASE_BRANCH"
    log_error "  2. Ensure coverage reports are committed to the base branch"
    exit 1
else
    # Determine merge base for PRs, or use HEAD^ for main branch commits
    if [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ]; then
        # On main branch - compare against previous commit
        BASE_COMMIT=$(git rev-parse HEAD^ 2>/dev/null) || BASE_COMMIT=""

        if [ -z "$BASE_COMMIT" ]; then
            # This is likely the first commit in the repo
            COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
            if [ "$COMMIT_COUNT" = "1" ]; then
                log_success "This is the first commit in the repository"
                log_success "Coverage ${CURRENT_COVERAGE}% will be used as baseline for future comparisons"
                exit 0
            fi
            log_warning "No previous commit found. Skipping comparison."
        else
            log_info "Comparing against previous commit: $(git rev-parse --short HEAD^)"
            BASE_COMMIT=$(git rev-parse HEAD^)
        fi
    else
        # On feature branch - compare against merge base
        BASE_COMMIT=$(git merge-base HEAD "origin/$BASE_BRANCH" 2>/dev/null) || \
        BASE_COMMIT=$(git merge-base HEAD "$BASE_BRANCH" 2>/dev/null) || \
        BASE_COMMIT=""

        if [ -z "$BASE_COMMIT" ]; then
            log_warning "Could not determine merge base. Skipping comparison."
        else
            log_info "Merge base commit: $(git rev-parse --short "$BASE_COMMIT")"
        fi
    fi

    if [ -n "$BASE_COMMIT" ]; then
        # Try to fetch coverage data from GitHub API/artifacts first, then fall back to git
        BASE_COVERAGE=""

        # Try GitHub API/artifacts (if available)
        if [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            if [ -f "$SCRIPT_DIR/fetch-coverage-github.sh" ]; then
                BASE_COVERAGE_DATA=$(bash "$SCRIPT_DIR/fetch-coverage-github.sh" "$BASE_COMMIT" "$BASE_BRANCH" 2>/dev/null || echo "")
                if [ -n "$BASE_COVERAGE_DATA" ]; then
                    BASE_COVERAGE=$(echo "$BASE_COVERAGE_DATA" | python3 -c "
import json
import sys
try:
    data = json.load(sys.stdin)
    print(f\"{data.get('coverage', 0):.2f}\")
except:
    print('')
" 2>/dev/null || echo "")
                fi
            fi
        fi

        # Fallback: Try to find coverage data from base commit in git history
        # (This is a temporary fallback during migration from git-based storage)
        BASE_COVERAGE_FILE="$COVERAGE_REPORT_DIR/coverage-${BASE_COMMIT:0:8}.json"

        # Check if coverage file exists in current working directory (from previous runs)
        if [ -f "$BASE_COVERAGE_FILE" ]; then
            log_info "Found coverage file for base commit: $BASE_COVERAGE_FILE"
            BASE_COVERAGE=$(python3 -c "
import json
try:
    with open('$BASE_COVERAGE_FILE', 'r') as f:
        data = json.load(f)
    print(f\"{data.get('coverage', 0):.2f}\")
except:
    print('')
" 2>/dev/null || echo "")
        fi

        # If not found locally, try to get from git history
        if [ -z "$BASE_COVERAGE" ]; then
            log_info "Checking git history for coverage data..."

            # Look for coverage JSON files in the base commit
            COVERAGE_FILES=$(git ls-tree -r --name-only "$BASE_COMMIT" 2>/dev/null | \
                            grep -E "^coverage-reports/coverage-.*\.json$" || echo "")

            if [ -n "$COVERAGE_FILES" ]; then
                # Get the most recent coverage file from base commit
                LATEST_COVERAGE_FILE=$(echo "$COVERAGE_FILES" | sort -r | head -1)
                log_info "Found coverage file in git: $LATEST_COVERAGE_FILE"

                BASE_COVERAGE=$(git show "$BASE_COMMIT:$LATEST_COVERAGE_FILE" 2>/dev/null | python3 -c "
import json
import sys
try:
    data = json.load(sys.stdin)
    coverage = data.get('coverage', 0)
    if isinstance(coverage, (int, float)):
        print(f'{coverage:.2f}')
    else:
        print('')
except:
    print('')
" 2>/dev/null || echo "")
            fi
        fi

        # If still not found, try to find coverage from commits near the base commit
        if [ -z "$BASE_COVERAGE" ] || [ "$BASE_COVERAGE" = "0.00" ]; then
            log_info "Searching nearby commits for coverage data..."
            # Look for coverage files in commits up to 10 commits before base
            for i in $(seq 0 10); do
                CHECK_COMMIT=$(git rev-parse "$BASE_COMMIT~$i" 2>/dev/null || echo "")
                if [ -z "$CHECK_COMMIT" ]; then
                    break
                fi

                COVERAGE_FILES=$(git ls-tree -r --name-only "$CHECK_COMMIT" 2>/dev/null | \
                                grep -E "^coverage-reports/coverage-.*\.json$" | head -1 || echo "")

                if [ -n "$COVERAGE_FILES" ]; then
                    LATEST_COVERAGE_FILE=$(echo "$COVERAGE_FILES" | head -1)
                    log_info "Found coverage file in nearby commit: $LATEST_COVERAGE_FILE"

                    BASE_COVERAGE=$(git show "$CHECK_COMMIT:$LATEST_COVERAGE_FILE" 2>/dev/null | python3 -c "
import json
import sys
try:
    data = json.load(sys.stdin)
    coverage = data.get('coverage', 0)
    if isinstance(coverage, (int, float)) and coverage > 0:
        print(f'{coverage:.2f}')
    else:
        print('')
except:
    print('')
" 2>/dev/null || echo "")

                    if [ -n "$BASE_COVERAGE" ] && [ "$BASE_COVERAGE" != "0.00" ]; then
                        break
                    fi
                fi
            done
        fi

        # If still not found, fail with helpful error message
        if [ -z "$BASE_COVERAGE" ] || [ "$BASE_COVERAGE" = "0.00" ]; then
            log_error "Could not find coverage data for base commit: $(git rev-parse --short "$BASE_COMMIT")"
            log_error ""
            log_error "Coverage reports must be committed to git for comparison."
            log_error "GitHub Actions should automatically commit coverage reports."
            log_error ""
            log_error "To fix:"
            log_error "  1. Ensure coverage reports exist in git history"
            log_error "  2. Check if CI is committing coverage reports"
            log_error "  3. Manually commit: make coverage && make coverage-commit"
            exit 1
        fi

        if [ -n "$BASE_COVERAGE" ] && [ "$BASE_COVERAGE" != "0.00" ]; then
            log_info "Base branch coverage: ${BASE_COVERAGE}%"

            # Compare with tolerance
            COVERAGE_DIFF=$(echo "$CURRENT_COVERAGE - $BASE_COVERAGE" | bc -l)

            if (( $(echo "$COVERAGE_DIFF < -$TOLERANCE" | bc -l) )); then
                log_error "Coverage regression detected!"
                log_error "  Base branch: ${BASE_COVERAGE}%"
                log_error "  Current:     ${CURRENT_COVERAGE}%"
                log_error "  Change:      ${COVERAGE_DIFF}%"
                log_error ""
                log_error "Code coverage has decreased. Please add tests to restore coverage."
                exit 1
            elif (( $(echo "$COVERAGE_DIFF > $TOLERANCE" | bc -l) )); then
                log_success "Coverage improved by ${COVERAGE_DIFF}%!"
            else
                log_success "Coverage maintained (change: ${COVERAGE_DIFF}%)"
            fi
        fi
    fi
fi

# Save current coverage with commit hash for future comparisons
# Include file-level coverage data for file-by-file comparison
COVERAGE_DATA_FILE="$COVERAGE_REPORT_DIR/coverage-${CURRENT_COMMIT:0:8}.json"
COVERAGE_JSON_TEMP=$(mktemp)
xcrun xccov view --report --json "$XCRESULT_PATH" > "$COVERAGE_JSON_TEMP" 2>/dev/null || {
    log_warning "Failed to extract detailed coverage data"
    rm -f "$COVERAGE_JSON_TEMP"
    COVERAGE_JSON_TEMP=""
}

# Extract file-level coverage data
FILE_COVERAGE_DATA=$(python3 << PYTHON_SCRIPT
import json
import sys
import os

try:
    temp_file = '$COVERAGE_JSON_TEMP'
    if temp_file and os.path.exists(temp_file):
        with open(temp_file, 'r') as f:
            data = json.load(f)

        files = {}
        targets = data.get('targets', [])

        for target in targets:
            target_name = target.get('name', '')
            if 'MyTree' not in target_name or 'Test' in target_name:
                continue

            for file_info in target.get('files', []):
                file_path = file_info.get('path', '')
                if '/Test' in file_path or '.generated' in file_path or 'Test' in file_path:
                    continue

                if '/MyTree/' in file_path:
                    rel_path = file_path.split('/MyTree/')[-1]
                else:
                    rel_path = file_path

                line_coverage = file_info.get('lineCoverage', {})
                if not line_coverage:
                    continue

                total_lines = len(line_coverage)
                covered_lines = sum(1 for covered in line_coverage.values() if covered)
                coverage_pct = (covered_lines / total_lines * 100) if total_lines > 0 else 0

                files[rel_path] = {
                    'coverage': round(coverage_pct, 2),
                    'covered': covered_lines,
                    'total': total_lines
                }

        print(json.dumps(files))
    else:
        print('{}')
except:
    print('{}')
PYTHON_SCRIPT
)

rm -f "$COVERAGE_JSON_TEMP"

cat > "$COVERAGE_DATA_FILE" << EOF
{
  "coverage": $CURRENT_COVERAGE,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "git_commit": "$CURRENT_COMMIT",
  "git_branch": "$CURRENT_BRANCH",
  "base_branch": "$BASE_BRANCH",
  "files": $FILE_COVERAGE_DATA
}
EOF

log_info "Coverage data saved to: $COVERAGE_DATA_FILE"

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
echo "  Base Branch:  ${BASE_COVERAGE:-N/A}%"
echo "  Threshold:    ${MIN_COVERAGE_THRESHOLD}%"
echo ""
echo "  Report:       $COVERAGE_TXT"
echo "  Raw Data:     $CURRENT_COVERAGE_JSON"
echo "  Commit Data:  $COVERAGE_DATA_FILE"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_success "Coverage check passed!"
exit 0
