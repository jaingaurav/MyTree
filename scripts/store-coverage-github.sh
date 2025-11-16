#!/bin/bash
#
# store-coverage-github.sh
#
# Stores coverage data for GitHub Actions artifacts (CI only).
# This script should only be run in CI - local coverage reports are stored locally only.
#
# Usage:
#   ./scripts/store-coverage-github.sh <xcresult-path> [commit-sha]
#
# Arguments:
#   xcresult-path  - Path to .xcresult bundle
#   commit-sha     - (Optional) Git commit SHA. Defaults to HEAD
#

set -euo pipefail

# Only run in CI (GitHub Actions)
if [ -z "${GITHUB_ACTIONS:-}" ]; then
    echo "⚠️  This script is for CI only. Local coverage reports are stored locally in coverage-reports/"
    exit 0
fi

XCRESULT_PATH="${1:-}"
COMMIT_SHA="${2:-${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}}"
COVERAGE_REPORT_DIR="./coverage-reports"

# If path not provided, try to find test results
if [ -z "$XCRESULT_PATH" ]; then
    # Try common locations
    if [ -d "./build/TestResults.xcresult" ]; then
        XCRESULT_PATH="./build/TestResults.xcresult"
    elif [ -d "./build/build/TestResults.xcresult" ]; then
        XCRESULT_PATH="./build/build/TestResults.xcresult"
    elif [ -d "$BUILD_DIR/TestResults.xcresult" ]; then
        XCRESULT_PATH="$BUILD_DIR/TestResults.xcresult"
    else
        echo "Error: xcresult path not provided and not found in common locations"
        echo "   Tried: ./build/TestResults.xcresult, ./build/build/TestResults.xcresult"
        exit 1
    fi
fi

if [ ! -d "$XCRESULT_PATH" ]; then
    echo "Error: Invalid xcresult path: $XCRESULT_PATH"
    echo "   Current directory: $(pwd)"
    echo "   Available files in build/:"
    ls -la build/ 2>/dev/null | head -10 || echo "   (build directory not found)"
    exit 1
fi

# Extract coverage data
COVERAGE_JSON=$(mktemp)
xcrun xccov view --report --json "$XCRESULT_PATH" > "$COVERAGE_JSON" 2>/dev/null || {
    echo "Error: Failed to extract coverage data"
    exit 1
}

# Extract coverage percentage and file-level data
COVERAGE_DATA=$(python3 << PYTHON_SCRIPT
import json
import sys
import os

try:
    coverage_json = '$COVERAGE_JSON'
    with open(coverage_json, 'r') as f:
        data = json.load(f)

    coverage_pct = data.get('lineCoverage', 0) * 100

    # Extract file-level coverage
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
            coverage_pct_file = (covered_lines / total_lines * 100) if total_lines > 0 else 0

            files[rel_path] = {
                'coverage': round(coverage_pct_file, 2),
                'covered': covered_lines,
                'total': total_lines
            }

    commit_sha = '$COMMIT_SHA'
    result = {
        'coverage': round(coverage_pct, 2),
        'commit': commit_sha,
        'timestamp': __import__('datetime').datetime.utcnow().isoformat() + 'Z',
        'files': files
    }

    print(json.dumps(result))
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
)

rm -f "$COVERAGE_JSON"

# Save locally for artifacts (GitHub Actions will upload)
mkdir -p "$COVERAGE_REPORT_DIR"
COVERAGE_FILE="$COVERAGE_REPORT_DIR/coverage-${COMMIT_SHA:0:8}.json"
echo "$COVERAGE_DATA" > "$COVERAGE_FILE"

echo "✅ Coverage data saved to: $COVERAGE_FILE"
echo "   Coverage: $(echo "$COVERAGE_DATA" | python3 -c "import json,sys; print(f\"{json.load(sys.stdin)['coverage']:.2f}%\")")"

# In GitHub Actions, this will be uploaded as an artifact
# The artifact will be named "coverage-data" and can be retrieved later

