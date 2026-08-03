# Folio Cloud & Backend Architecture

Folio Cloud is the backend service ecosystem for Folio. While the client application is privacy-first and fully functional offline without any cloud dependencies, Folio Cloud provides server infrastructure for:
- Remote encrypted backups and cross-device sync
- Cloud AI completion and transcription (Quill Cloud / Ink drops)
- Web publishing (`publishedPages`)
- Cloud user authentication, subscription entitlements, and admin controls
- Real-time collaboration via WebSockets (STOMP)

> [!NOTE]
> **Firebase Deprecation**: Firebase Cloud Functions and Firestore have been completely removed. Folio backend is entirely powered by the **Spring Boot** architecture (`backend/` submodule).

---

## Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                          Folio Client                                  │
│             (Flutter Desktop - Windows, macOS, Linux)                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                         REST API & WebSocket STOMP
                        (http / https & ws / wss)
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Spring Boot API Backend                         │
│                    (Java 21 / Spring Boot 3 Engine)                    │
└─────────┬─────────────────────────┬──────────────────────────┬─────────┘
          │                         │                          │
          ▼                         ▼                          ▼
 ┌─────────────────┐       ┌─────────────────┐        ┌─────────────────┐
 │   PostgreSQL    │       │    MinIO / S3   │        │     Stripe      │
 │ (Relational DB) │       │ (Object Storage)│        │ (Webhooks & API)│
 └─────────────────┘       └─────────────────┘        └─────────────────┘
```

---

## Core Infrastructure Stack

### 1. Spring Boot API Service (`backend/`)
- **Submodule Location**: `backend/` (repository: [`Minealex2001/Folio-Backend`](https://github.com/Minealex2001/Folio-Backend)).
- **Runtime**: Java 21, Spring Boot 3, Spring Security (JWT authentication), JPA / Hibernate.
- **REST Endpoints**: `/api/v1/...` for auth, entitlements, AI completions, backups, and user management.
- **Real-Time Collaboration**: WebSocket STOMP protocol on `/ws/collab`.
- **Interactive Documentation**: Swagger UI at `/swagger-ui/index.html`.

### 2. Database & Persistence Layer
- **PostgreSQL**: Stores relational data (`users`, `user_folio_cloud`, `subscriptions`, `published_pages`, `vault_backups`).
- **MinIO / AWS S3 Compatible**: Handles object storage for encrypted vault backup archives and published HTML pages.

---

## Client Integration Protocol

The Flutter client communicates with the Spring Boot backend using:
- **REST API**: HTTP Bearer JWT authentication headers (`Authorization: Bearer <JWT>`).
- **WebSocket STOMP**: Dual-channel encrypted real-time collaboration (`ws://` or `wss://`).

Compile or run the client pointing to your Spring Boot instance:

```powershell
flutter run -d windows `
  --dart-define=FOLIO_BACKEND_MODE=spring `
  --dart-define=FOLIO_BACKEND_BASE_URL=http://127.0.0.1:18080
```

---

## Navigation & Cloud Guides

- **[Deployment & Environment Setup](DEPLOYMENT_AND_ENV.md)**: Running Docker Compose self-host and deploying to production / Railway.
- **[Integrations & Payments](INTEGRATIONS_AND_PAYMENTS.md)**: Stripe payment webhooks, Admin entitlement grants, and Ink AI drops.
- **[Secrets Management](SECRETS.md)**: Environment variables (`backend/.env`), JWT signing keys, and secrets configuration.
