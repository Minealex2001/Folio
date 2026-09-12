# Folio Testing Strategy & Guidelines

This document outlines the testing architecture, quality assurance standards, and PR submission expectations for Folio.

---

## 1. Testing Objectives

- **Prevent Regressions**: Ensure core editor, vault encryption, and data transformations remain stable.
- **Fast Feedback Loop**: Maintain rapid execution speed for unit and widget tests.
- **Release Confidence**: High test coverage across core domain models, session lifecycles, and backend integrations.

---

## 2. Test Layer Architecture

The test suite in `test/` mirrors the structure of `lib/`:

```text
test/
├── app/         # App settings & composition tests
├── crypto/      # Cryptographic & key derivation tests
├── data/        # Repository & serialization tests
├── models/      # Domain model unit tests
├── services/    # AI, cloud, and HTTP service mocks & tests
├── session/     # Vault lifecycle & lock/unlock state tests
└── workspace/   # Widget tests for block editor & navigation
```

### Test Layers Defined

1. **Unit Tests** (`test/models/`, `test/services/`, `test/crypto/`):
   - Fast, isolated tests for pure Dart logic, models, encryption, and data transformations.
   - Avoid disk/network calls; use in-memory fakes.

2. **Widget Tests** (`test/workspace/`, `test/app/`):
   - Test UI components, block rendering, shortcut handlers, and user input workflows.
   - Verify state transitions without external platform dependencies.

3. **Integration Tests** (`test/integration/`):
   - Multi-component flows: vault backup export/import, sync conflict resolution, and cloud entitlement transitions.

---

## 3. Coverage Policy & Commands

- **Local Validation**: Refer to **[DEVELOPMENT.md](DEVELOPMENT.md)** for initial environment setup.
- **Coverage Generation**:
  ```bash
  flutter test --coverage
  ```
  Generates LCOV report at `coverage/lcov.info`.

---

## 4. Priority Areas for Test Coverage

When contributing new features, ensure test coverage for:
1. Block editor state, undo/redo stacks, and Markdown serialization.
2. Encrypted vault locking/unlocking and password derivation.
3. Device synchronization and conflict resolution logic.
4. Cloud AI error handling, drop balances, and retry policies.

---

## 5. Pull Request Test Plan Template

Every Pull Request must include a completed test summary:

```markdown
### PR Test Summary
- **Tested Scenarios**: [List key flows tested]
- **Verification Commands Executed**:
  - `flutter analyze`
  - `flutter test`
- **Results**: All tests passing cleanly (0 failures)
- **Known Gaps / Follow-ups**: [None or list follow-up items]
```
