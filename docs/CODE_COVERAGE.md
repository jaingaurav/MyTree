# Code Coverage

This document describes the code coverage setup and requirements for MyTree.

## Overview

Code coverage is automatically measured for all tests and tracked using **[Codecov](https://codecov.io)**.
Coverage data is uploaded to Codecov on every PR and push, providing beautiful visualizations,
historical tracking, and automatic PR comments without cluttering the git repository.

## Codecov Integration

### What is Codecov?

[Codecov](https://codecov.io) is an industry-standard coverage reporting service that provides:

- 📊 **Interactive dashboards** - Browse coverage by file with line-by-line visualization
- 📈 **Historical trends** - Track coverage changes over time
- 💬 **Automatic PR comments** - See coverage impact directly in PRs
- 🎯 **Coverage badges** - Display coverage status in README
- 🆓 **Free for open source** - No cost for public repositories

### How It Works

On every PR/push:

1. Tests run with code coverage enabled
2. Coverage data is extracted from Xcode test results
3. Coverage is uploaded to Codecov automatically
4. Codecov comments on PRs with coverage changes
5. Coverage checks prevent merging if coverage decreases

### Coverage Requirements

Codecov enforces these requirements (configured in `codecov.yml`):

- **Minimum coverage**: 50% overall
- **Regression tolerance**: Coverage can't drop by more than 0.5%
- **Patch coverage**: New code should have 80%+ coverage
- **PR comments**: Codecov automatically comments on PRs showing coverage changes

### Viewing Coverage

**On Codecov Dashboard**: https://codecov.io/gh/jaingaurav/MyTree

- Interactive file browser with line-by-line coverage
- Coverage trends and graphs
- Sunburst chart showing file coverage
- Compare coverage across branches

**In Pull Requests**: Codecov automatically comments with:

- Overall coverage change
- File-by-file coverage breakdown
- Line-by-line diff showing which new code is covered
- Links to detailed reports

## Running Tests with Coverage

### Local Development

```bash
# Run tests with coverage
make coverage

# Check coverage meets minimum threshold
make coverage-check

# Display coverage report
make coverage-report
```

Coverage reports are stored locally in `coverage-reports/` (ignored by git).
In CI, coverage is automatically uploaded to Codecov for comparison and tracking.

### CI/CD

Code coverage is automatically:

- Collected during test runs
- Uploaded to Codecov
- Compared against the base branch (for PRs)
- Displayed in PR comments by Codecov
- Tracked over time on the Codecov dashboard

## Coverage Requirements

### Minimum Threshold

- **Minimum coverage:** 50%
- Tests will fail if coverage drops below this threshold
- Enforced locally by `make coverage-check` and in CI by Codecov

### Regression Prevention

- Coverage must not decrease by more than 0.5% from the base branch
- Any PR that decreases coverage will be flagged by Codecov
- If coverage decreases, add tests to restore it before merging
- Codecov automatically compares your PR against the base branch

### Improving Coverage

When you improve code coverage:

1. Run tests with coverage:

   ```bash
   make coverage
   ```

2. Check the coverage report locally:

   ```bash
   make coverage-report
   ```

3. Push your changes - Codecov will automatically:
   - Upload and compare coverage
   - Comment on your PR showing improvements
   - Update coverage trends

## Coverage Reports

### Viewing Reports

**On Codecov** (recommended):

- Visit https://codecov.io/gh/jaingaurav/MyTree
- Browse files with interactive line-by-line coverage
- View coverage trends over time
- See coverage for specific commits or PRs

**Locally** after running `make coverage`:

- `coverage-reports/coverage-report.txt` - Human-readable report
- `coverage-reports/coverage.json` - Machine-readable data
- `build/UnitTestResults.xcresult` - Xcode result bundle

**In Xcode**:

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

### Coverage Check Fails in CI

If Codecov reports coverage decreased:

1. **View Codecov comment** on your PR to see which files lost coverage

2. **Check coverage locally**:

   ```bash
   make coverage-report
   ```

3. **Identify untested code**:
   - Look at the coverage report
   - Focus on files with low coverage
   - Check which functions are untested

4. **Add tests**:
   - Write tests for uncovered code
   - Run `make coverage-check` to verify it meets threshold
   - Push changes and Codecov will update

### "Codecov token not found" Error

If CI fails with Codecov token errors:

1. Verify `CODECOV_TOKEN` is set in GitHub repository secrets
2. Check the secret name matches exactly (case-sensitive)
3. Contact a maintainer to re-generate the token from Codecov if needed

### Coverage Not Uploading

If coverage doesn't appear on Codecov:

1. Check the CI workflow logs for upload errors
2. Verify test results exist: `./build/UnitTestResults.xcresult`
3. Ensure `coverage.json` is generated in `coverage-reports/`
4. Check that tests are actually running in CI

## Integration with CI

The GitHub Actions workflow (`.github/workflows/ci.yml`) includes:

1. **Test Job**:
   - Runs tests with coverage enabled
   - Generates coverage reports

2. **Coverage Check Job**:
   - Extracts coverage from Xcode test results
   - Checks minimum coverage threshold (50%)
   - Uploads coverage to Codecov
   - Codecov automatically compares against base branch

3. **Status Checks**:
   - **Coverage check is a required status check** - PRs cannot be merged if it fails
   - Codecov status check shows coverage change
   - Both `test` and `coverage-check` jobs must pass to merge

**⚠️ Important**: Pull requests cannot be merged if:

- Tests fail (`test` job)
- Coverage is below 50% threshold
- Coverage decreases by more than 0.5% (enforced by Codecov)

See [Branch Protection Requirements](BRANCH_PROTECTION.md) for details on configuring required checks.

## Configuration

Coverage behavior is configured in `codecov.yml`:

```yaml
coverage:
  status:
    project:
      default:
        target: auto
        threshold: 0.5%  # Allow 0.5% decrease

    patch:
      default:
        target: 80%  # New code should have high coverage
```

This configuration:

- Allows coverage to drop by at most 0.5%
- Requires new code (patches) to have 80%+ coverage
- Automatically comments on PRs with coverage changes
- Ignores test files from coverage calculations

## Goals

- **Maintain high coverage**: Target 70%+ over time
- **Prevent regressions**: Never decrease coverage
- **Focus on critical code**: Prioritize testing core business logic
- **Stable tests**: All tests should be reliable and fast

## Related Documentation

- [Contributing Guide](../CONTRIBUTING.md) - How to contribute
- [Architecture Documentation](ARCHITECTURE.md) - System architecture and design
