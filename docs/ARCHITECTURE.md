# Architecture and System Conventions

This document describes Folio's core application architecture, directory structure, and technical conventions.

---

## 1. High-Level Layering

The codebase in `lib/` follows a clean, layered architecture:

- `lib/app`: Application composition, global settings, and theme tokens.
- `lib/features`: UI components, block editor views, and feature-specific logic.
- `lib/services`: Cross-cutting integrations (local AI, cloud APIs, sync, system tray).
- `lib/data`: Data access, database providers, and format adapters.
- `lib/session`: Vault lifecycle management, lock state, and session security.
- `lib/models`: Domain models and immutability structures.
- `lib/crypto`: Encryption utilities (AES-GCM, PBKDF2).
- `lib/l10n`: Translations and generated localization artifacts.

---

## 2. Core Design Principles

- **Local-First & Privacy Preserving**: Data remains local on device by default. Cloud features are strictly opt-in.
- **Layer Separation**: Business logic and state management are decoupled from presentation widgets.
- **Defense in Depth**: Secure defaults for local vault storage, HTTP integrations, and AI endpoints.
- **Traceability**: Comprehensive unit/widget test suite colocated with implementation code.

---

## 3. Local AI System (`lib/services/ai`)

AI capabilities are encapsulated within `lib/services/ai`:
- Support for local inference providers (`ollama`, `lmStudio`, `none`).
- Endpoints default to local loopback addresses (`127.0.0.1`).
- Optional cloud inference via Quill Cloud (see **[cloud/INTEGRATIONS_AND_PAYMENTS.md](cloud/INTEGRATIONS_AND_PAYMENTS.md)**).

---

## 4. Multi-Package Dependency Rationale

The `pubspec.yaml` contains pairs of packages that may appear redundant at first glance. They serve non-overlapping jobs:

- **`webview_flutter` + `webview_windows`**: `webview_flutter` lacks native Windows embedding. `webview_windows` is selected conditionally on Windows at runtime (`lib/features/workspace/editor/folio_embed_webview.dart`).
- **`markdown` + `flutter_markdown_plus`**: `markdown` is the AST parser used for walking and transforming markdown structures (`lib/features/workspace/history/mermaid_markdown_builder.dart`). `flutter_markdown_plus` is the rendering widget for preview UI.
- **`syncfusion_flutter_pdfviewer` + `syncfusion_flutter_pdf` + `pdf`**:
  - `syncfusion_flutter_pdfviewer`: Interactive PDF viewer widget (`lib/features/workspace/editor/file_video_previews.dart`).
  - `syncfusion_flutter_pdf`: Reads/annotates existing PDFs (`lib/features/workspace/shell/workspace_page.dart`).
  - `pdf`: Pure Dart PDF generation library for page exports (`lib/services/folio_cloud/folio_page_pdf_export.dart`).

---

## 5. System Documentation Map

For detailed subsystems, consult:
- **[Development Guide](DEVELOPMENT.md)**: Environment setup, daily workflow, compilation flags.
- **[Testing Strategy](TESTING.md)**: Testing layers, coverage policy, PR guidelines.
- **[Cloud & Backend System](cloud/README.md)**: Firebase Functions & Spring Boot self-host architecture.
- **[Local HTTP Integration](integrations/LOCAL_HTTP_API.md)**: Deep link & local API contract.
- **[Platform Desktop Guides](platform/WINDOWS_DESKTOP.md)**: System tray and taskbar behaviors.
