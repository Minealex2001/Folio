# Folio Documentation Hub

Welcome to the central documentation index for **Folio**. This hub organizes technical guides, architecture specifications, cloud setup, and integration contracts.

---

## 🗺️ Documentation Map

### 🚀 Getting Started & Development
- **[DEVELOPMENT.md](DEVELOPMENT.md)**: Environment prerequisites, daily workflow, i18n (`flutter gen-l10n`), local AI setup (Ollama / LM Studio), compilation flags, and troubleshooting.
- **[ARCHITECTURE.md](ARCHITECTURE.md)**: Architectural layers, design principles, module organization, and dependency rationale.
- **[TESTING.md](TESTING.md)**: Testing strategy, unit/widget/integration layers, code coverage policies, and PR test templates.
- **[RELEASES.md](RELEASES.md)**: Version history, release changelogs, and tag milestones.

---

## 📋 Product & Feature Specifications
- **[FEATURES.md](FEATURES.md)**: *(Untouched Roadmap)* Complete feature overview, phase tracking, roadmap, and capabilities matrix.

---

## ☁️ Cloud & Backend Infrastructure (`docs/cloud/`)
- **[cloud/README.md](cloud/README.md)**: Folio Cloud architecture (Firebase Cloud Functions v1/v2 + Spring Boot dual-mode).
- **[cloud/DEPLOYMENT_AND_ENV.md](cloud/DEPLOYMENT_AND_ENV.md)**: Staging vs Production deployment, Storage CORS setup, and Docker Compose self-host environment.
- **[cloud/INTEGRATIONS_AND_PAYMENTS.md](cloud/INTEGRATIONS_AND_PAYMENTS.md)**: Stripe billing/webhooks, Microsoft Store entitlement validation, and Ink drops / Quill Cloud AI.
- **[cloud/SECRETS.md](cloud/SECRETS.md)**: Secrets management policies for Stripe, OpenAI/Quill, Azure AD, and Spring Boot environment variables.

---

## 🔌 Integrations & Platform Guides
- **[integrations/LOCAL_HTTP_API.md](integrations/LOCAL_HTTP_API.md)**: Local HTTP API contract (`http://127.0.0.1:45831`) and Deep Link protocol (`folio://import`) for 3rd-party apps.
- **[platform/APP_STORE_GUIDE.md](platform/APP_STORE_GUIDE.md)**: Folio App (`.folioapp`) packaging and App Store developer submission guide.
- **[platform/WINDOWS_DESKTOP.md](platform/WINDOWS_DESKTOP.md)**: Windows desktop behavior (System Tray vs Taskbar jump lists).

---

## 🔍 Spikes, Proposals & Migrations
- **[spikes/COLLAB_CRDT.md](spikes/COLLAB_CRDT.md)**: Research spike on real-time collaboration with Yjs & CRDTs.
- **[spikes/PUSH_NOTIFICATIONS.md](spikes/PUSH_NOTIFICATIONS.md)**: Research spike on FCM & Web Push notifications.
- **[spikes/SLACK_TEAMS.md](spikes/SLACK_TEAMS.md)**: Planned integration proposal for Slack and Microsoft Teams.
- **[migrations/ELECTRON_TO_FLUTTER.md](migrations/ELECTRON_TO_FLUTTER.md)**: Historical runbook for migrating from Electron to Flutter.
- **[migrations/SPRINGBOOT_BACKEND.md](migrations/SPRINGBOOT_BACKEND.md)**: Migration guide from Cloud Functions to Spring Boot backend.

---

## 🔒 Compliance & Security
- **[AI_COMPLIANCE.md](AI_COMPLIANCE.md)**: EU AI Act transparency, AI data policies, model cards, and user privacy guarantees.
- **[TELEMETRY.md](TELEMETRY.md)**: Google Analytics (GA4) setup across platforms and user opt-in/opt-out configuration.
- **[../SECURITY.md](../SECURITY.md)**: Security policy, vulnerability disclosure, and GitHub repository security hardening.
