#!/bin/bash
#
# fetch-coverage-github.sh
#
# Fetches coverage data from GitHub Actions artifacts or API.
# Falls back to git history if GitHub API is unavailable.
#
# Usage:
#   ./scripts/fetch-coverage-github.sh <commit-sha> [base-branch]
#
# Arguments:
#   commit-sha   - Git commit SHA to fetch coverage for
#   base-branch  - (Optional) Base branch name (default: main)
#
# Output:
#   Prints coverage JSON to stdout, or empty if not found
#

set -euo pipefail

COMMIT_SHA="${1:-}"
BASE_BRANCH="${2:-main}"

if [ -z "$COMMIT_SHA" ]; then
    echo "Error: Commit SHA required" >&2
    exit 1
fi

# Try to fetch from GitHub Actions artifacts API
# This requires GITHUB_TOKEN and GITHUB_REPOSITORY to be set
if [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
    # Try to fetch from artifacts
    # Note: GitHub Actions artifacts API requires listing runs first
    # For now, we'll use a simpler approach: try to fetch from git history as fallback

    # Check if we can access GitHub API
    API_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/commits/$COMMIT_SHA" 2>/dev/null || echo "")

    if [ -n "$API_RESPONSE" ]; then
        # GitHub API is available, but artifacts require more complex logic
        # For now, fall through to git-based approach
        :
    fi
fi

# Fallback: Try to fetch from git history (if coverage was previously committed)
# This is a temporary fallback during migration
if git rev-parse --git-dir > /dev/null 2>&1; then
    COVERAGE_FILES=$(git ls-tree -r --name-only "$COMMIT_SHA" 2>/dev/null | \
                    grep -E "^coverage-reports/coverage-.*\.json$" | sort -r | head -1 || echo "")

    if [ -n "$COVERAGE_FILES" ]; then
        git show "$COMMIT_SHA:$COVERAGE_FILES" 2>/dev/null || echo ""
        exit 0
    fi
fi

# If not found, return empty (will trigger "no baseline" behavior)
echo ""

