# Contributing to MyTree

Thank you for your interest in contributing to MyTree! We welcome contributions of all kinds: bug fixes, features,
documentation, and more.

## Quick Start

1. Fork the repository
2. Clone your fork: `git clone <your-fork-url>`
3. Set up development environment: `make setup`
4. Create a feature branch: `git checkout -b feature/your-feature`
5. Make your changes and test: `make test`
6. Commit following conventions: `git commit -m "feat: description"`
7. Push and create a pull request

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on what's best for the project
- Show empathy towards others

## Development Guidelines

### Quick Reference

```bash
make setup      # Set up git hooks
make macos      # Build macOS app
make test       # Run tests
make clean      # Clean build artifacts
```

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Test additions/modifications
- `refactor:` - Code restructuring
- `perf:` - Performance improvements
- `chore:` - Maintenance tasks

**Examples:**

```bash
git commit -m "feat: add spouse connection animation"
git commit -m "fix: correct parent centering calculation"
git commit -m "docs: update architecture diagrams"
```

### Code Style

- Follow SwiftLint rules (`.config/.swiftlint.yml`)
- Use `// MARK: -` to organize code sections
- Document public APIs with `///` comments
- Keep functions under 50 lines when possible
- Prefer `let` over `var` when possible

### Testing

- Write tests for new functionality
- Use descriptive test names
- Follow Arrange-Act-Assert pattern
- Ensure all tests pass before submitting PR
- **Maintain or improve code coverage** - Coverage must not decrease

#### Code Coverage Requirements

- **Minimum coverage:** 50% (enforced in CI)
- **No regressions:** Coverage cannot decrease by more than 0.5%
- Run `make coverage-check` to verify before submitting PR
- See [Code Coverage Documentation](docs/CODE_COVERAGE.md) for details

```bash
make test-coverage     # Run tests with coverage
make coverage-check    # Verify coverage requirements
make coverage-report   # View detailed coverage report
```

## Pull Request Process

### Before Submitting

- [ ] All tests pass (`make test`)
- [ ] Code coverage maintained (`make coverage-check`)
- [ ] SwiftLint passes (automatic with git hooks)
- [ ] Documentation updated (if needed)
- [ ] Code is self-reviewed
- [ ] No unrelated changes included

### PR Checklist

1. **Clear Description** - Explain what and why
2. **Tests Added** - For new features/fixes
3. **Coverage Maintained** - No decrease in code coverage
4. **Documentation Updated** - For user-facing changes
5. **Single Purpose** - One feature/fix per PR

### Review Process

1. Automated checks will run (tests, coverage, linting)
2. A maintainer will review your PR
3. Address any requested changes
4. Once approved, maintainer will merge

**Note:** PRs that decrease code coverage will fail CI and require additional tests.

## Reporting Issues

### Bug Reports

Include:

- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- macOS/iOS version, Xcode version
- Screenshots if applicable

### Feature Requests

Include:

- Problem you're trying to solve
- Proposed solution
- Alternative approaches considered
- Use cases and examples

## Developer Documentation

For detailed information on architecture, design principles, and development setup, see:

- **[Developer Documentation](docs/README.md)** - Complete developer guide
- **[Architecture Overview](docs/ARCHITECTURE.md)** - System design and patterns
- **[Code Coverage Guide](docs/CODE_COVERAGE.md)** - Coverage requirements and testing

## Getting Help

- Check [Developer Documentation](docs/README.md)
- Review existing issues and PRs
- Look at test cases for examples
- Open an issue for questions

## License and Contributor Agreement

This project is licensed under the [GNU Affero General Public License v3.0 (AGPLv3)](LICENSE).

### Contributor License Agreement (CLA)

By submitting a contribution to this project (including but not limited to code,
documentation, bug reports, feature requests, or any other materials), you agree to
the following terms:

1. **Copyright Assignment**: You hereby assign all rights, title, and interest in your
   contribution, including all copyright and related rights, to Gaurav Jain.

2. **License Grant**: If the assignment in (1) is not effective for any reason, you
   grant Gaurav Jain a perpetual, worldwide, non-exclusive, royalty-free, irrevocable
   license (with the right to sublicense) to use, reproduce, modify, prepare derivative
   works of, publicly display, publicly perform, and distribute your contribution and
   such derivative works.

3. **Original Work**: You represent that each of your contributions is your original
   creation and you have the legal right to make the assignment and grant the license
   described above.

4. **Public License**: Your contributions will be made available to the public under
   the AGPLv3 license, but the copyright holder (Gaurav Jain) reserves the right to
   license the project under different terms, including proprietary licenses.

### What This Means

- The project is open source under **AGPLv3** (strong copyleft)
- Anyone can use, modify, and distribute the code under AGPLv3 terms
- If you use this code in a network service, you must make the source available
- **You assign ownership of your contributions to the project maintainer**
- This allows dual-licensing and commercial licensing arrangements
- Similar to MongoDB's contribution model

See the [LICENSE](LICENSE) file for complete AGPLv3 terms.

For alternative licensing arrangements, contact `gaurav@gauravjain.org`

---

Thank you for making MyTree better! 🎉
