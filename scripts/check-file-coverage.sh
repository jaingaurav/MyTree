#!/bin/bash
#
# check-file-coverage.sh
#
# Checks file-level coverage to prevent regressions in individual files.
# This ensures that someone can't reduce coverage in one file while increasing
# coverage elsewhere.
#
# Usage:
#   ./scripts/check-file-coverage.sh <xcresult-path> [base-branch]
#
# Arguments:
#   xcresult-path  - Path to .xcresult bundle from xcodebuild test
#   base-branch    - (Optional) Base branch to compare against (default: main)
#
# Exit Codes:
#   0 - All files meet coverage requirements
#   1 - Coverage regression detected in one or more files
#

set -euo pipefail

XCRESULT_PATH="${1:-}"
BASE_BRANCH="${2:-main}"
COVERAGE_REPORT_DIR="./coverage-reports"
COVERAGE_REGRESSION_TOLERANCE=5.0  # Allow 5% decrease before failing

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

if [ -z "$XCRESULT_PATH" ] || [ ! -d "$XCRESULT_PATH" ]; then
    log_error "Missing or invalid xcresult path: $XCRESULT_PATH"
    exit 1
fi

log_info "Checking file-level coverage..."

# Extract current file coverage
CURRENT_COVERAGE_JSON=$(mktemp)
xcrun xccov view --report --json "$XCRESULT_PATH" > "$CURRENT_COVERAGE_JSON" 2>/dev/null || {
    log_error "Failed to extract coverage data"
    exit 1
}

# Get base branch coverage if available
BASE_COVERAGE_JSON=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    if [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ]; then
        BASE_COMMIT=$(git rev-parse HEAD^ 2>/dev/null || echo "")
    else
        BASE_COMMIT=$(git merge-base HEAD "origin/$BASE_BRANCH" 2>/dev/null || \
                     git merge-base HEAD "$BASE_BRANCH" 2>/dev/null || echo "")
    fi

    if [ -n "$BASE_COMMIT" ]; then
        # Try to find file-level coverage data from base commit
        COVERAGE_FILES=$(git ls-tree -r --name-only "$BASE_COMMIT" 2>/dev/null | \
                        grep -E "^coverage-reports/coverage-.*\.json$" | sort -r | head -1 || echo "")

        if [ -n "$COVERAGE_FILES" ]; then
            BASE_COVERAGE_FILE=$(echo "$COVERAGE_FILES" | head -1)
            BASE_COVERAGE_CONTENT=$(git show "$BASE_COMMIT:$BASE_COVERAGE_FILE" 2>/dev/null || echo "")

            if [ -n "$BASE_COVERAGE_CONTENT" ]; then
                BASE_COVERAGE_JSON=$(mktemp)
                echo "$BASE_COVERAGE_CONTENT" > "$BASE_COVERAGE_JSON"
                log_info "Found base coverage data at commit: $(git rev-parse --short "$BASE_COMMIT")"
            fi
        fi
    fi
fi

# Analyze file-level coverage
python3 << 'PYTHON_SCRIPT'
import json
import sys
import os

try:
    current_file = '$CURRENT_COVERAGE_JSON'
    with open(current_file, 'r') as f:
        current_data = json.load(f)

    base_data = None
    base_file = '$BASE_COVERAGE_JSON'
    if base_file and os.path.exists(base_file):
        try:
            with open(base_file, 'r') as f:
                base_data = json.load(f)
        except:
            pass

    # Get file-level coverage from current data
    current_files = {}
    targets = current_data.get('targets', [])

    for target in targets:
        target_name = target.get('name', '')
        if 'MyTree' not in target_name or 'Test' in target_name:
            continue  # Skip test targets

        files = target.get('files', [])
        for file_info in files:
            file_path = file_info.get('path', '')
            # Skip test files and generated files
            if '/Test' in file_path or '.generated' in file_path or 'Test' in file_path:
                continue

            # Get relative path
            if '/MyTree/' in file_path:
                rel_path = file_path.split('/MyTree/')[-1]
            else:
                rel_path = file_path

            line_coverage = file_info.get('lineCoverage', {})
            if not line_coverage:
                continue

            # Calculate coverage percentage
            total_lines = len(line_coverage)
            covered_lines = sum(1 for covered in line_coverage.values() if covered)
            coverage_pct = (covered_lines / total_lines * 100) if total_lines > 0 else 0

            current_files[rel_path] = {
                'coverage': coverage_pct,
                'covered': covered_lines,
                'total': total_lines
            }

    # Get base file coverage if available
    base_files = {}
    if base_data and 'files' in base_data:
        base_files = base_data['files']
    elif base_data and 'targets' in base_data:
        for target in base_data.get('targets', []):
            target_name = target.get('name', '')
            if 'MyTree' not in target_name or 'Test' in target_name:
                continue

            files = target.get('files', [])
            for file_info in files:
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

                base_files[rel_path] = {
                    'coverage': coverage_pct,
                    'covered': covered_lines,
                    'total': total_lines
                }

    # Compare file-level coverage
    regressions = []
    improvements = []

    for file_path, current_info in sorted(current_files.items()):
        current_cov = current_info['coverage']
        base_info = base_files.get(file_path)

        if base_info:
            base_cov = base_info['coverage']
            diff = current_cov - base_cov

            if diff < -$COVERAGE_REGRESSION_TOLERANCE:
                regressions.append({
                    'path': file_path,
                    'old': base_cov,
                    'new': current_cov,
                    'diff': diff
                })
            elif diff > $COVERAGE_REGRESSION_TOLERANCE:
                improvements.append({
                    'path': file_path,
                    'old': base_cov,
                    'new': current_cov,
                    'diff': diff
                })

    # Report results
    if regressions:
        print(f"\n❌ File coverage regressions detected ({len(regressions)} file(s)):")
        for reg in regressions:
            print(f"  {reg['path']}: {reg['old']:.1f}% → {reg['new']:.1f}% ({reg['diff']:+.1f}%)")
        print("")
        sys.exit(1)

    if improvements:
        print(f"\n✅ File coverage improvements ({len(improvements)} file(s)):")
        for imp in improvements[:5]:  # Show first 5
            print(f"  {imp['path']}: {imp['old']:.1f}% → {imp['new']:.1f}% ({imp['diff']:+.1f}%)")
        if len(improvements) > 5:
            print(f"  ... and {len(improvements) - 5} more")
        print("")

    if not base_files:
        print("\nℹ️  No base coverage data found - skipping file-level comparison")
    else:
        print(f"\n✅ File-level coverage check passed ({len(current_files)} files checked)")

except Exception as e:
    print(f"Error analyzing coverage: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_SCRIPT

EXIT_CODE=$?
rm -f "$CURRENT_COVERAGE_JSON" "$BASE_COVERAGE_JSON"

if [ $EXIT_CODE -ne 0 ]; then
    log_error "File-level coverage check failed"
    exit 1
fi

log_success "File-level coverage check completed"
exit 0
