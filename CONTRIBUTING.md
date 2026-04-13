# Contribution Guide

Thanks for contributing to Folio.

This document defines the recommended workflow to keep technical consistency and
make reviews smoother.

## Types of contributions

- Bug fixes
- New features
- Performance improvements
- Documentation improvements
- Automated tests
- Internationalization updates (`lib/l10n/*.arb` files)

## Workflow

1. Fork (if needed) and create a branch from `main`:
   - `feat/short-name`
   - `fix/short-name`
   - `docs/short-name`
2. Keep changes small and focused.
3. Run local validation.
4. Open a PR with clear description, motivation, and evidence.

## Required checks before opening a PR

```bash
flutter pub get
flutter analyze
flutter test
flutter test --coverage
```

If you changed localization:

```bash
flutter gen-l10n
```

For testing conventions and scope by layer, see `docs/TESTING.md`.

## Code conventions

- Follow lints defined in `analysis_options.yaml`.
- Prioritize small, reviewable changes.
- Avoid introducing technical debt without documenting it.
- Do not mix large refactors and functional fixes in the same PR.

## Commit conventions

Use atomic commits with these prefixes:

- `feat:`
- `fix:`
- `refactor:`
- `test:`
- `docs:`
- `chore:`

Example:

```text
feat: add validation for AI base URL in settings
```

## Pull Requests

Include at minimum:

- Problem being solved
- Applied solution
- Risks or side effects
- Test plan (what you ran and results)
- Screenshots/video for relevant UI changes

Suggested checklist:

- [ ] `flutter analyze` with no new issues
- [ ] `flutter test` passing
- [ ] `flutter test --coverage` generated report
- [ ] Documentation updated when behavior changes
- [ ] No build or temporary files in the diff

## Issues

When reporting a bug, include:

- Reproduction steps
- Expected result
- Actual result
- Platform (Windows/macOS/Linux/Web)
- Flutter version (`flutter --version`)

## Security and sensitive data

- Do not publish secrets, tokens, or personal data.
- If you find a vulnerability, avoid posting public exploit details; share
  context with maintainers responsibly.
