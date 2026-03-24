# Folio

A personal productivity app built with Flutter. Folio combines content
management (pages, blocks, files) with local AI utilities, focused on desktop
workflows and privacy by default.

## Project status

This project is under active development. Structure and technical decisions may
still evolve, so contributions are welcome.

## Tech stack

- Flutter / Dart (Dart SDK `^3.11.1`)
- Layered architecture in `lib/` (app, features, services, data, session)
- Internationalization support (`lib/l10n`)
- Tests in `test/`

## Requirements

- Stable Flutter installed and configured
- Dart (bundled with Flutter)
- Git
- (Optional) Ollama or LM Studio for local AI feature testing

## Quick start

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

If you are developing on another platform, change the target device (`-d`)
accordingly.

## Useful development commands

```bash
# Static analysis
flutter analyze

# Run all tests
flutter test

# Run a subset of tests
flutter test test/services

# Regenerate localizations (after changing .arb files)
flutter gen-l10n
```

## Repository structure

```text
lib/
  app/         # Global app config, theme, settings
  features/    # UI and feature-specific logic
  services/    # Cross-cutting services and integrations (including AI)
  data/        # Data access and transformation
  session/     # Vault session and main working state
  l10n/        # Translations and generated localization code
test/          # Test suite
```

## Documentation

- Contribution guide: `CONTRIBUTING.md`
- Development guide: `docs/DEVELOPMENT.md`
- Architecture and conventions: `docs/ARCHITECTURE.md`
- Security policy: `SECURITY.md`
- GitHub repository security setup: `docs/REPO_SECURITY_SETUP.md`

## How to contribute

1. Read `CONTRIBUTING.md`.
2. Create a branch from `main`.
3. Make sure `flutter analyze` and `flutter test` pass.
4. Open a Pull Request with clear context for your changes.

## Privacy and security notes

- AI integrations are designed to use local endpoints by default.
- Do not include secrets or personal data in issues, commits, or PRs.
- Do not commit build artifacts (`build/`, `.dart_tool/`), already ignored by
  `.gitignore`.
