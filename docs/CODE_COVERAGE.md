# Code Coverage

This document describes the code coverage setup and requirements for MyTree.

## Overview

Code coverage is automatically measured for all tests and checked in CI to
prevent regressions. Coverage data is stored in **GitHub Actions artifacts** (not in git),
providing historical coverage tracking without cluttering the repository.

## Coverage Storage

### GitHub Actions Artifacts (Primary Storage)

Coverage data is stored outside the git repository:

- **Storage Location**: GitHub Actions artifacts
- **Retention**: 365 days for individual coverage snapshots, 90 days for aggregated reports
- **Access**: Available via GitHub Actions UI or API
- **Benefits**:
  - ✅ Keeps repository clean (coverage reports not committed)
  - ✅ Long-term historical data (1 year retention)
  - ✅ Automatic storage with each CI run
  - ✅ Easy access via GitHub UI

### Coverage Comparison

Coverage comparison works by:

- **For Pull Requests**: Coverage is compared against the merge base with the base branch
- **For Main Branch**: Coverage is compared against the previous commit
- **Data Source**: Fetches coverage data from GitHub Actions artifacts (falls back to git history during migration)
- **File-Level**: Also checks file-level coverage to prevent regressions in individual files

This approach ensures:

- ✅ No coverage files committed to git
- ✅ Historical coverage data available via GitHub Actions
- ✅ PRs compare against actual base branch coverage
- ✅ File-level coverage regression detection

## Running Tests with Coverage

### Local Development

```bash
# Run tests with coverage
make coverage

# Check coverage against base branch
make coverage-check

# Display coverage report
make coverage-report

# Note: Coverage data is automatically stored in GitHub Actions artifacts
# No need to commit coverage reports to git
```

### CI/CD

Code coverage is automatically:

- Collected during the test job
- **Compared against the base branch** (for PRs) or previous commit (for main)
- **Stored in GitHub Actions artifacts** (365 day retention)
- Reported in the GitHub Actions summary
- Uploaded as artifacts for review
- **Not committed to git** - keeps repository clean

## Coverage Requirements

### Minimum Threshold

- **Minimum coverage:** 50%
- Tests will fail if coverage drops below this threshold

### Regression Prevention

- Coverage must not decrease by more than 0.5% from the base branch/previous commit
- Any PR that decreases coverage will fail the coverage check
- If coverage decreases, add tests to restore it before merging
- Coverage comparison is automatic - no manual baseline updates needed

### Improving Coverage

When you improve code coverage:

1. Run tests with coverage:

   ```bash
   make coverage
   ```

2. Check the improvement (automatically compares against base branch):

   ```bash
   make coverage-check
   ```

3. Coverage data is automatically stored:

   Coverage data is automatically stored in GitHub Actions artifacts when tests run in CI.
   No manual steps needed - the system will compare your PR against the base branch's
   coverage automatically.

## Coverage Reports

### Viewing Reports

After running `make coverage`, reports are available locally in:

- `coverage-reports/coverage-report.txt` - Human-readable report
- `coverage-reports/coverage-*.json` - Machine-readable data (indexed by commit hash)
- `build/TestResults.xcresult` - Xcode result bundle

**Note**: These files are in `.gitignore` and are not committed to git. In CI,
coverage data is stored as GitHub Actions artifacts (retained for 365 days),
providing historical coverage tracking without cluttering the repository.

### Viewing in Xcode

1. Run tests in Xcode (Cmd+U)
2. Open the Report Navigator (Cmd+9)
3. Select the latest test run
4. Click the "Coverage" tab
5. View coverage by file/function

## Understanding Coverage

### Line Coverage

The primary metric is **line coverage** - the percentage of executable lines that are executed during tests.

### What Counts

- All non-comment, non-blank lines in Swift files
- Lines in test files are excluded from coverage
- Generated code may be excluded

### Coverage by Module

Code coverage is measured for the **MyTree** target (main application code).

**Test Targets:**

- **MyTreeIntegrationTests** - Integration tests that exercise the application code
- **MyTreeUnitTests** - Unit tests for isolated components

Both test targets contribute to measuring coverage of the main application. The test
code itself is excluded from coverage metrics (as is standard practice - you measure
coverage of production code, not test code).

## Best Practices

### When Writing Tests

1. **Test New Code**: All new features should include tests
2. **Cover Edge Cases**: Test error conditions and boundary cases
3. **Avoid Flaky Tests**: Tests should be deterministic
4. **Test Sorting Logic**: Critical algorithms (like sidebar sorting) need comprehensive tests

### When Reviewing PRs

1. Check if coverage decreased
2. Ensure new code has corresponding tests
3. Review coverage report in artifacts
4. Look for untested critical paths

### Exceptions

Some code may be difficult or unnecessary to test:

- UI-only code (consider UI tests instead)
- Auto-generated code
- Trivial getters/setters

Use `// swiftlint:disable:next function_body_length` or similar for justified exceptions.

## Troubleshooting

### Coverage Check Fails

If the coverage check fails:

1. **View the report**:

   ```bash
   make coverage-report
   ```

2. **Identify untested code**:
   - Look at the coverage report
   - Focus on files with low coverage
   - Check which functions are untested

3. **Add tests**:
   - Write tests for uncovered code
   - Run `make coverage-check` to verify improvement

4. **Commit coverage reports** (if on main branch):

   ```bash
   make coverage-commit  # Commits coverage reports to git
   ```

   Note: GitHub Actions automatically commits coverage reports for PRs.

### Missing Coverage History

If git-based comparison fails (no coverage history in git):

**This should not happen** - GitHub Actions automatically commits coverage reports.

If it does happen:

1. **Check CI logs**: Verify coverage reports were committed
2. **Manual commit**: Run tests and commit coverage reports:

   ```bash
   make coverage
   make coverage-commit
   ```

3. **Verify**: Ensure coverage reports exist in git history:

   ```bash
   git log --all --oneline -- coverage-reports/  # --oneline is a git flag
   ```

Coverage comparison requires coverage reports to be committed to git - there is no fallback mechanism.

### CI Coverage Check Fails

If CI fails on coverage:

1. Pull the latest baseline from main
2. Run coverage locally
3. Add tests to restore coverage
4. Verify with `make coverage-check`
5. Push changes

## Scripts

### check-coverage.sh

Located at `scripts/check-coverage.sh`, this script:

- Extracts coverage from .xcresult bundles
- **Requires git-based comparison** (compares against base branch)
- Fails with clear error if coverage data not found in git
- Enforces minimum threshold
- Generates reports

### check-coverage-git.sh

Located at `scripts/check-coverage-git.sh`, this script:

- Performs git-based coverage comparison
- Compares against merge base (for PRs) or previous commit (for main)
- Retrieves coverage data from git history
- Saves coverage data with commit hash for future comparisons

## Integration with CI

The GitHub Actions workflow (`.github/workflows/ci.yml`) includes:

1. **Test Job**:
   - Fetches base branch for comparison (for PRs)
   - Runs tests with coverage enabled
   - **Checks coverage against base branch** (git-based comparison)
   - Generates coverage report
   - Uploads results as artifacts
   - Stores coverage data as GitHub Actions artifacts

2. **Coverage Artifacts**:
   - `test-results` - Full .xcresult bundle
   - `coverage-reports` - Human-readable reports and JSON data

3. **Status Checks**:
   - **Coverage check is a required status check** - PRs cannot be merged if it fails
   - Coverage check runs as separate job (`coverage-check`) after tests pass
   - Prevents accidental coverage regression
   - Automatically compares against base branch state
   - Both `test` and `coverage-check` jobs must pass to merge

**⚠️ Important**: The `coverage-check` job is a **required status check**. Pull requests cannot be merged if:

- Tests fail (`test` job)
- Coverage check fails (`coverage-check` job)
- Coverage decreases below threshold
- Coverage regresses from base branch

See [Branch Protection Requirements](BRANCH_PROTECTION.md) for details on configuring required checks.

## Goals

- **Maintain high coverage**: Target 70%+ over time
- **Prevent regressions**: Never decrease coverage
- **Focus on critical code**: Prioritize testing core business logic
- **Stable tests**: All tests should be reliable and fast

## Related Documentation

- [Contributing Guide](../CONTRIBUTING.md) - How to contribute
- [Architecture Documentation](ARCHITECTURE.md) - System architecture and design
