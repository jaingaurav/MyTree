# Branch Protection Requirements

This document describes the branch protection rules and required status checks for the MyTree repository.

## Required Status Checks

The following GitHub Actions jobs **must pass** before code can be merged into `main` or `develop`:

### 1. **Pre-commit Checks** (`lint`)

- **Job Name**: `Pre-commit Checks`
- **Status Check**: `lint`
- **What it checks**:
  - SwiftLint code style enforcement
  - Markdown formatting
  - Spelling checks
  - Link validation
- **Failure**: PR cannot be merged if linting fails

### 2. **Run Tests** (`test`)

- **Job Name**: `Run Tests`
- **Status Check**: `test`
- **What it checks**:
  - All unit tests pass
  - All integration tests pass
  - Tests run with code coverage enabled
- **Failure**: PR cannot be merged if any test fails
- **Artifacts**: Uploads test results for coverage analysis

### 3. **Check Code Coverage** (`coverage-check`)

- **Job Name**: `Check Code Coverage`
- **Status Check**: `coverage-check`
- **What it checks**:
  - Code coverage meets minimum threshold (50%)
  - Code coverage does not decrease from base branch
  - Coverage comparison against git history or baseline
- **Failure**: PR cannot be merged if:
  - Coverage drops below 50%
  - Coverage decreases by more than 0.5% from base branch
- **Dependencies**: Requires `test` job to pass first

## Setting Up Branch Protection

To enforce these requirements, configure branch protection rules in GitHub:

### Steps to Configure

1. Go to **Settings** → **Branches** in your GitHub repository
2. Click **Add rule** or edit existing rule for `main` (and `develop` if needed)
3. Configure the following:

#### Required Settings

- ✅ **Require a pull request before merging**
  - ✅ Require approvals: `1` (or more as needed)
  - ✅ Dismiss stale pull request approvals when new commits are pushed

- ✅ **Require status checks to pass before merging**
  - ✅ Require branches to be up to date before merging
  - **Required status checks** (select all):
    - `lint` - Pre-commit Checks
    - `test` - Run Tests
    - `coverage-check` - Check Code Coverage

- ✅ **Require conversation resolution before merging** (optional but recommended)

- ✅ **Do not allow bypassing the above settings** (recommended for main branch)

#### Optional but Recommended

- ✅ Require linear history
- ✅ Include administrators
- ✅ Restrict pushes that create files larger than 100MB

### Example Branch Protection Configuration

```yaml
Branch: main
Protection Rules:
  - Require pull request reviews: 1 approval
  - Require status checks:
      - lint
      - test
      - coverage-check
  - Require branches to be up to date: Yes
  - Require conversation resolution: Yes
  - Do not allow bypassing: Yes
  - Include administrators: Yes
```

## How It Works

### For Pull Requests

1. **Developer creates PR** → Triggers CI workflow
2. **Lint job runs** → Checks code style and formatting
3. **Test job runs** → Executes all tests with coverage
4. **Coverage-check job runs** → Compares coverage against base branch
5. **All checks must pass** → PR can be merged
6. **Any check fails** → PR is blocked from merging

### Status Check Behavior

- **`lint` fails**: Fix linting errors and push again
- **`test` fails**: Fix failing tests and push again
- **`coverage-check` fails**:
  - If coverage below threshold: Add tests to increase coverage
  - If coverage decreased: Add tests to restore coverage level
  - Push changes to trigger re-check

### Coverage Check Details

The coverage check will fail if:

1. **Coverage below minimum**: Current coverage < 50%

   ```text
   ❌ Coverage 45.2% is below minimum threshold of 50.0%
   ```

2. **Coverage regression**: Coverage decreased by > 0.5% from base branch

   ```text
   ❌ Coverage regression detected!
     Base branch: 64.30%
     Current:     63.50%
     Change:      -0.80%
   ```

3. **Test results missing**: No test results available for analysis

   ```text
   ❌ Test results not found
   ```

## Bypassing Checks (Not Recommended)

⚠️ **Warning**: Bypassing required checks should only be done in emergencies and requires administrator privileges.

If you must bypass (not recommended):

1. Go to PR → **Merge** dropdown
2. Select **Merge without waiting for requirements to be met**
3. Provide justification in commit message
4. Consider creating an issue to track why bypass was needed

## Troubleshooting

### Check Not Showing Up

If a required check doesn't appear:

1. **Check workflow file**: Ensure `.github/workflows/ci.yml` defines the job
2. **Check job name**: Status check name matches job `name:` field
3. **Wait for completion**: Checks appear after workflow runs
4. **Check branch**: Ensure PR targets protected branch (`main`/`develop`)

### Check Stuck

If a check appears stuck:

1. **Re-run workflow**: Go to Actions tab → Re-run failed jobs
2. **Check workflow logs**: Look for errors in the job logs
3. **Verify dependencies**: Ensure upstream jobs (like `test`) completed successfully

### Coverage Check Failing

If coverage check fails:

1. **View coverage report**: Check artifacts in Actions tab
2. **Compare against base**: See what coverage was before your changes
3. **Add tests**: Write tests for uncovered code paths
4. **Re-run**: Push new commit to trigger re-check

## Best Practices

1. **Run checks locally first**:

   ```bash
   make lint          # Check linting
   make test          # Run tests
   make coverage-check # Check coverage
   ```

2. **Fix issues before pushing**: Saves CI time and resources

3. **Keep PRs small**: Easier to review and less likely to cause coverage issues

4. **Add tests with new code**: Maintain or improve coverage with each PR

5. **Monitor coverage trends**: Use coverage reports to track project health

## Related Documentation

- [Code Coverage Guide](CODE_COVERAGE.md) - Detailed coverage documentation
- [Contributing Guide](../CONTRIBUTING.md) - How to contribute to the project
- [CI/CD Workflows](../.github/workflows/README.md) - Workflow documentation
