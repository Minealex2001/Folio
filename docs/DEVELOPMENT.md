# Local development

This guide explains how to run Folio locally and contribute with minimal setup
friction.

## Requirements

- Stable Flutter SDK
- Git
- Platform build tooling (for example, Visual Studio Build Tools on Windows)

## First run

```bash
flutter pub get
flutter analyze
flutter test
flutter test --coverage
flutter run -d windows
```

## Recommended daily workflow

```bash
# Pull latest changes
git pull

# Work on your own branch
git checkout -b feat/my-change

# Validate before commit
flutter analyze
flutter test
flutter test --coverage
```

## Localization (i18n)

Source files:

- `lib/l10n/app_es.arb`
- `lib/l10n/app_en.arb`

Generated code:

- `lib/l10n/generated/*`

When you modify `.arb` files, run:

```bash
flutter gen-l10n
```

## Local AI (optional for development)

Folio supports local AI providers such as Ollama or LM Studio.

Default reference endpoints:

- Ollama: `http://127.0.0.1:11434`
- LM Studio: `http://127.0.0.1:1234`

If you are not working on AI features, these services are not required.

## Testing

Run everything:

```bash
flutter test
```

Run with coverage report:

```bash
flutter test --coverage
```

Run a subset (example):

```bash
flutter test test/services
```

For testing scope, layering, and PR expectations, see `docs/TESTING.md`.

## Common issues

- Outdated dependencies after switching branches:
  - Run `flutter pub get`.
- Localization errors:
  - Validate `.arb` format and run `flutter gen-l10n`.
- Local artifacts appearing in git:
  - Check you are not staging content from `build/` or `.dart_tool/`.
