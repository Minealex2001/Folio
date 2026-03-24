# Architecture and conventions

This document describes Folio's current structure to help onboarding and keep
technical decisions consistent.

## Overview

The app is organized into layers with clear responsibilities:

- `lib/app`: app composition, theme, global settings
- `lib/features`: UI and feature-specific logic
- `lib/services`: cross-cutting integrations (for example, AI)
- `lib/data`: data access and transformation
- `lib/session`: main session state and vault lifecycle
- `lib/models`: domain models
- `lib/l10n`: translations and generated artifacts

## Design principles

- Keep feature changes small and focused
- Separate UI from business logic where possible
- Prefer secure defaults (especially for network and AI)
- Keep traceability: tests and docs alongside behavior changes

## AI in the application

AI capabilities are encapsulated in `lib/services/ai`.

Key points:

- Supported providers in settings (`ollama`, `lmStudio`, `none`)
- Local endpoints by default
- Security and validation policies centralized in AI services

## Settings persistence

`lib/app/app_settings.dart` persists user preferences (`SharedPreferences`),
including:

- theme/language
- vault lock behavior
- hotkeys and system tray
- AI configuration

## Testing

The `test/` folder mirrors key functional domains (`data`, `models`,
`services`, `session`).

When adding new functionality:

- prioritize unit tests for logic
- include widget tests for relevant UI changes

## Collaboration conventions

- Document behavior changes in `README.md` or `docs/`.
- Avoid unnecessary coupling between features.
- If a technical decision has trade-offs, record it in the PR.
