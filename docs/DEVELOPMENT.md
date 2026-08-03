# Local Development & Workflow Guide

This guide explains how to set up, build, and contribute to Folio with minimal setup friction.

---

## 1. Environment Requirements

- **Flutter SDK**: Stable channel (version 3.11.1 or later)
- **Dart SDK**: Included with Flutter
- **Git**: Version control (including Git submodules support)
- **Platform Build Tools**:
  - **Windows**: Visual Studio 2022 with *Desktop development with C++* workload
  - **macOS**: Xcode & CocoaPods
  - **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`
- **(Optional)**: Local AI tools (Ollama or LM Studio)

---

## 2. Initial Repository Setup

```bash
# 1. Clone repository with submodules (includes backend/ -> Folio-Backend)
git clone --recurse-submodules https://github.com/Minealex2001/Folio.git
cd Folio

# If cloned without submodules:
# git submodule update --init --recursive

# 2. Fetch Flutter packages
flutter pub get

# 3. Verify static code analysis
flutter analyze

# 4. Run test suite
flutter test

# 5. Launch desktop app (Windows)
flutter run -d windows
```

---

## 3. Recommended Daily Workflow

```bash
# Pull latest changes
git pull

# Create feature branch
git checkout -b feat/my-new-feature

# Validate code before committing
flutter analyze
flutter test

# Run tests with coverage
flutter test --coverage
```

---

## 4. Internationalization (i18n / Localization)

Folio uses Flutter's ARB-based localization system.

**Source Translation Files**:
- `lib/l10n/app_es.arb` (Spanish)
- `lib/l10n/app_en.arb` (English)

**Generated Code Directory**:
- `lib/l10n/generated/`

Whenever you add or update strings in `.arb` files, run:

```bash
flutter gen-l10n
```

---

## 5. Local AI Assistant Setup (Optional)

Folio connects directly to local AI providers without requiring API keys or internet access.

### Ollama Setup
1. Download & install from [ollama.ai](https://ollama.ai).
2. Serve local models: `ollama serve`
3. Default endpoint: `http://127.0.0.1:11434`

### LM Studio Setup
1. Download & install from [lmstudio.ai](https://lmstudio.ai).
2. Start the local server inside LM Studio.
3. Default endpoint: `http://127.0.0.1:1234`

Select your preferred provider in **Folio Settings -> AI Provider**.

---

## 6. Compilation Flags & Environment Overrides

When running or building Folio, you can pass custom `--dart-define` flags:

```bash
# Enable Web Portal link options
flutter run -d windows --dart-define=FOLIO_WEB_PORTAL_LINK_ENABLED=true

# Target Firebase Staging environment
flutter run -d windows --dart-define=FOLIO_FIREBASE_ENV=staging

# Target Self-Hosted Spring Boot backend API
flutter run -d windows --dart-define=FOLIO_BACKEND_MODE=spring --dart-define=FOLIO_BACKEND_BASE_URL=http://127.0.0.1:18080

# Configure Microsoft Store product definitions
flutter run -d windows --dart-define=MS_STORE_PRODUCT_FOLIO_CLOUD_MONTHLY=...
```

---

## 7. Testing Strategy

For detailed testing architecture, mocking guidelines, and PR test templates, consult **[TESTING.md](TESTING.md)**.

Quick test commands:
- Run all unit & widget tests: `flutter test`
- Run service tests: `flutter test test/services/`
- Generate coverage info (`coverage/lcov.info`): `flutter test --coverage`

---

## 8. Common Issues & Troubleshooting

- **Outdated dependencies after switching branches**:
  - Run `flutter pub get`.
- **Localization missing or compilation errors**:
  - Validate `.arb` JSON syntax and run `flutter gen-l10n`.
- **Accidental staging of build artifacts**:
  - Check `git status` to ensure `build/`, `.dart_tool/`, or `.env` files are ignored.
- **Port conflicts on Windows (`127.0.0.1:8080`)**:
  - Avoid hardcoding `localhost:8080` due to Windows CEF/Cursor debugger listeners; use `127.0.0.1:18080` for self-host backends.
