# Testing Strategy

This document defines the baseline testing strategy for Folio.

## Goals

- Prevent regressions in core flows.
- Keep PR feedback fast and reliable.
- Increase confidence for releases.

## Test layers

1. Unit tests
- Focus on models, pure services, parsers, and utility code.
- Must run quickly and avoid network/filesystem unless explicitly required.

2. Widget tests
- Focus on user-critical UI behavior and state transitions.
- Cover workspace interactions, settings forms, and lock/unlock flows.

3. Integration tests
- Focus on end-to-end feature slices and cross-service behavior.
- Prioritize sync/collaboration, cloud account, and onboarding paths.

## Coverage policy

- Run coverage in CI for every PR.
- Command: `flutter test --coverage`
- Coverage file: `coverage/lcov.info`
- Start by tracking baseline, then raise thresholds incrementally.

## Local validation before PR

```bash
flutter pub get
flutter analyze
flutter test
flutter test --coverage
```

## Mocking and fakes

- Prefer fakes/mocks for Firebase, HTTP, and platform services in unit tests.
- Keep test data in reusable fixtures.
- Avoid flaky tests that depend on timing or external services.

## Priority areas for new tests

1. Workspace editing and undo/redo behavior.
2. Device sync and collaboration conflict handling.
3. Cloud account and entitlement transitions.
4. Audio/transcription error paths and retries.

## PR test plan template

Include in each PR:

- What was tested.
- Commands executed.
- Results observed.
- Known gaps (if any) and follow-up task.
