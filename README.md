# Folio

A privacy-first personal productivity app built with **Flutter**. Folio combines unified content management (pages, blocks, files) with integrated local AI capabilities, optimized for desktop workflows where your data stays yours.

## Overview

Folio is designed for users who value privacy, control, and productivity. Whether you're managing notes, organizing files, or leveraging local AI for content enhancement, Folio provides a seamless desktop-first experience with no cloud dependencies by default.

**Key philosophy:** Privacy by design. All data processing happens locally, and AI integrations work entirely on your machine through providers like Ollama or LM Studio.

---

## ✨ Features

### Workspace & editing

- **Block-based pages**: Edit notes as a stack of blocks (similar to Notion-style tools), with markdown-oriented rendering and a dedicated block picker.
- **Rich block types**: Headings (H1–H3), paragraphs, quotes, dividers, **callouts**, linked **child pages**, bullet and numbered lists, **to-do lists**, **rich tasks** (status, priority, due dates), **toggles**, **columns**, **tables**, and a **database** block (beta) for list/table/board-style views.
- **Media & files**: Images, **video** and **audio** players, **bookmarks** with link previews, **code** blocks with syntax highlighting, **file attachments** and **PDF** viewing, and **web embeds** (e.g. YouTube, Figma, Docs-style content).
- **Diagrams & math**: **Mermaid** diagrams and **LaTeX** equations in the editor.
- **Page structure helpers**: **Table of contents** and **breadcrumb** blocks; **template buttons** to insert predefined content; **page outline** panel (auto outline from headings with jump-to-block navigation).
- **Navigation & history**: Sidebar with **vaults**, page tree, and **recent pages**; **global search** across the vault; **page history** to review past versions.

### Security, vault & sync

- **Encrypted vaults**: Local-first storage with cryptographic operations; **lock** the vault when you step away.
- **Local integrations (v2)**: The local integration bridge supports a current **v2** contract with mandatory encrypted content payloads, while **v1** remains legacy-compatible without content encryption.
- **Authentication**: **Local auth** (e.g. biometrics) and **passkeys** where supported, in addition to your vault password.
- **Optional device sync**: Pair devices and sync **between your own machines** (with conflict handling in settings)—not a mandatory cloud service.

### AI & productivity

- **Local AI**: Connect **Ollama** or **LM Studio** for on-device assistance (configurable endpoint and security posture in settings).
- **Desktop workflow**: **System tray**, **global hotkeys** (search, new page, settings, lock, page navigation, etc.—many are **customizable**), and **Windows taskbar** integration.

### Internationalization & offline use

- **English and Spanish** UI via ARB-based localization.
- **Offline-first**: Core functionality works without internet; cloud accounts are not required for day-to-day use.

---

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK**: Stable version (3.11.1 or later)
- **Dart**: Included with Flutter
- **Git**: For version control
- **Build Tools**: Platform-specific tools (e.g., Visual Studio Build Tools on Windows)
- **(Optional)** Ollama or LM Studio for local AI features

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/folio.git
cd folio

# 2. Install dependencies
flutter pub get

# 2b. Local dev secrets (optional but required for some integrations)
# Copy the example and fill in if you use Jira OAuth, Folio integration secret, etc.
# cp lib/config/folio_local_secrets.example.dart lib/config/folio_local_secrets.dart   # Unix
# Copy-Item lib/config/folio_local_secrets.example.dart lib/config/folio_local_secrets.dart   # PowerShell
# The copied file is gitignored. CI must create it the same way before `flutter analyze` / build.

# 3. Run static analysis
flutter analyze

# 4. Run tests (optional but recommended)
flutter test

# 5. Launch the app
flutter run -d windows
```

**Platform variants:**
- Windows: `flutter run -d windows`
- macOS: `flutter run -d macos`
- Linux: `flutter run -d linux`
- Mobile: Connect device and run `flutter run`

### Building without Folio Cloud

The core app (vault, editor, local device sync, local AI) works **without** Firebase, Stripe, or any paid backend. Optional **Folio Cloud** features (encrypted cloud backup/sync, hosted AI, publish to web) require a configured Firebase project and active subscription; they are disabled if Firebase fails to start. Contributors do not need production keys—see [docs/FOLIO_CLOUD_SECRETS.md](docs/FOLIO_CLOUD_SECRETS.md).

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines and code standards |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Local development setup and workflows |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Technical architecture and design patterns |
| [SECURITY.md](SECURITY.md) | Security policies and vulnerability reporting |
| [docs/REPO_SECURITY_SETUP.md](docs/REPO_SECURITY_SETUP.md) | GitHub repository security configuration |
| [docs/FOLIO_INTEGRATION.md](docs/FOLIO_INTEGRATION.md) | Integration guide for extensions and plugins |
| [docs/WINDOWS_TASKBAR.md](docs/WINDOWS_TASKBAR.md) | Windows-specific features and taskbar integration |
| [docs/FOLIO_CLOUD_SECRETS.md](docs/FOLIO_CLOUD_SECRETS.md) | Folio Cloud: secrets, OSS policy, builds without paid services |
| [docs/FOLIO_CLOUD_STRIPE_SETUP.md](docs/FOLIO_CLOUD_STRIPE_SETUP.md) | Stripe: `.env`, webhook, Stripe CLI, emulador |
| [docs/FOLIO_CLOUD_STRIPE_PRODUCTS.md](docs/FOLIO_CLOUD_STRIPE_PRODUCTS.md) | Stripe catalog (Folio Cloud + tinteros) and webhook notes |
| [docs/FOLIO_CLOUD_BACKEND.md](docs/FOLIO_CLOUD_BACKEND.md) | Server-authoritative Folio Cloud (Firestore, ink, idempotency) |

---

## 🛠️ Development

### Project Structure

```text
lib/
  ├── app/           # Global app configuration, theme, and settings
  ├── features/      # Feature modules (UI and feature-specific logic)
  ├── services/      # Cross-cutting services (AI integration, auth, etc.)
  ├── data/          # Data access and transformation layer
  ├── models/        # Domain models and data structures
  ├── session/       # Vault session management and working state
  ├── crypto/        # Cryptographic utilities
  ├── desktop/       # Desktop-specific features (tray, hotkeys)
  └── l10n/          # Translations and generated localization
  
test/               # Comprehensive test suite mirroring lib/
docs/               # Extended documentation
```

### Development Commands

```bash
# Code quality
flutter analyze                    # Static analysis
flutter test                       # Run all tests
flutter test test/services/        # Run specific test suite

# Localization
flutter gen-l10n                   # Regenerate translations after .arb changes

# Building
flutter build windows              # Build Windows release
flutter build linux                # Build Linux release
flutter build macos                # Build macOS release
flutter build apk                  # Build Android APK
flutter build web                  # Build web version

# Development
flutter run -d windows --debug     # Run with debug output
flutter run -d windows --release   # Run optimized release build
```

### Translation Workflow

1. Edit `.arb` files:
   - `lib/l10n/app_es.arb` (Spanish)
   - `lib/l10n/app_en.arb` (English)

2. Regenerate localization:
   ```bash
   flutter gen-l10n
   ```

3. Generated files update automatically in `lib/l10n/generated/`

### Local AI Setup (Optional)

Folio supports two local AI providers out-of-the-box:

#### Ollama
```bash
# Install from https://ollama.ai
ollama serve
# Default endpoint: http://127.0.0.1:11434
```

#### LM Studio
```bash
# Install from https://lmstudio.ai
# Start LM Studio, configure server
# Default endpoint: http://127.0.0.1:1234
```

Configure in Folio settings → AI Provider.

### Architecture Highlights

- **Layered Design**: Clean separation of concerns across app, features, services, and data layers
- **Secure by Default**: Cryptographic operations, local-only processing, no remote data transmission
- **Internationalization**: Full support for multiple languages via managed `.arb` files
- **Settings Persistence**: User preferences stored securely via `SharedPreferences`
- **Testing First**: Unit and widget tests colocated with features for maintainability

---

## 🔒 Security & Privacy

- **Data Locality**: All content and processing occurs locally; no cloud synchronization required
- **AI Integration**: Local AI providers (Ollama, LM Studio) run on your machine—no external API calls
- **Encryption**: Cryptographic operations powered by trusted libraries
- **Privacy-First Telemetry**: Telemetry enabled by default to improve the app, but you can disable it anytime in Settings. See [TELEMETRY.md](docs/TELEMETRY.md) for details
- **Safe Defaults**: Privacy-first settings out of the box

**See [SECURITY.md](SECURITY.md) for detailed security policies and vulnerability reporting guidelines.**

---

## 🐛 Troubleshooting

### Flutter not found
```bash
# Ensure Flutter is in your PATH
flutter --version

# If not found, add Flutter SDK to PATH according to your OS
```

### Dependency issues after branch switching
```bash
flutter pub get
flutter pub upgrade
```

### Tests not running
```bash
# Make sure Flutter test environment is configured
flutter test --verbose

# For specific test file:
flutter test test/services/ai_service_test.dart
```

### Local AI not connecting
- Verify Ollama/LM Studio is running: `http://127.0.0.1:11434` or `http://127.0.0.1:1234`
- Check Folio settings for correct provider and endpoint
- Ensure firewall allows local connections

### Hot reload issues
```bash
# Restart the app: R (in terminal)
# Full restart if hot reload fails: Shift+R
# Or restart from VS Code command palette
```

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Read** [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines
2. **Branch** from `main`: `git checkout -b feat/your-feature`
3. **Validate** before committing:
   ```bash
   flutter analyze
   flutter test
   ```
4. **Push** to your fork and open a Pull Request with clear context

---

## 📋 Project Status

This is an **actively developed project**. Structure and technical decisions may evolve. We appreciate feedback, bug reports, and contributions.

---

## 📦 Tech Stack

| Component | Technology |
|-----------|-----------|
| **Framework** | Flutter / Dart (3.11.1+) |
| **UI** | Flutter widgets, Cupertino (iOS) |
| **State** | Provider pattern with custom session management |
| **Data** | SQLite (via local file storage), SharedPreferences |
| **Crypto** | `cryptography` package (industry standard) |
| **Code Editor** | Flutter Code Editor with syntax highlighting |
| **PDFs** | Syncfusion Flutter PDF Viewer & PDF Kit |
| **Media** | Image Picker, File Picker, Video Player |
| **AI** | Ollama, LM Studio (via standard HTTP) |
| **Localization** | Flutter Localizations, ARB format |
| **Testing** | Flutter Test, widget and unit tests |

---

## 📄 License

See LICENSE file in the repository root.

---

## 💬 Support & Feedback

- **Issues**: Report bugs and request features via [GitHub Issues](https://github.com/yourusername/folio/issues)
- **Discussions**: Join project discussions on GitHub
- **Security**: Report security concerns privately via [SECURITY.md](SECURITY.md)

---

## 🎯 Roadmap & Future

Stay tuned for updates on:
- Broader optional **cloud** sync (beyond current **multi-device** pairing)
- Advanced AI integrations
- Mobile optimizations
- Plugin ecosystem
- Additional language support

---

**Built with ❤️ for privacy-conscious developers.**
