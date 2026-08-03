# Folio Cloud — Deployment & Environment Setup

This document covers deployment procedures and environment setup for the Folio Spring Boot API backend.

---

## 1. Local Development & Self-Host (Docker Compose)

The backend code lives in the **`backend/` git submodule** (repository: [`Minealex2001/Folio-Backend`](https://github.com/Minealex2001/Folio-Backend)).

Ensure submodules are initialized before starting:
```powershell
git submodule update --init --recursive
```

### Quick Start

From the root directory of the repository:

```powershell
# 1. Copy environment template
Copy-Item backend/.env.example backend/.env

# 2. Start services with Docker Compose
docker compose -f backend/docker-compose.yml --env-file backend/.env up -d --build
```

### Stack Components & Services

| Service | Host Port | Internal Port | Description |
|---------|-----------|---------------|-------------|
| `api` | **18080** | 8080 | Spring Boot API service (Spring Profile: `docker`) |
| `postgres` | **5432** | 5432 | PostgreSQL database (Volume: `folio_pg_data`) |
| `minio` | **9000 / 9001** | 9000 / 9001 | MinIO S3-compatible Object Storage & Console |
| `mailpit` | **1025 / 8025** | 1025 / 8025 | Local SMTP testing server & Web UI |

*Windows Note:* Use `http://127.0.0.1:18080` rather than `localhost:8080` to prevent port collisions with Win32/CEF processes.

### Verifying Service Health

```powershell
curl http://127.0.0.1:18080/api/v1/health
# Response: {"status":"ok"}
```

---

## 2. Spring Profiles

- **`dev` (`application-dev.yml`)**: Used for local host development (`mvn spring-boot:run`). Connects to `localhost:5432` and local MinIO.
- **`docker` (`application-docker.yml`)**: Used inside Docker Compose. Uses container hostnames (`postgres:5432`, `minio:9000`).
- **`prod` (`application-prod.yml`)**: Configured for cloud hosting (e.g. Railway or managed Kubernetes/VMs). Reads environment variables from system secrets.

---

## 3. Production & Cloud Hosting (e.g., Railway)

To deploy the backend to Railway or a remote cloud server:

1. Connect the GitHub repository [`Minealex2001/Folio-Backend`](https://github.com/Minealex2001/Folio-Backend) to your hosting provider.
2. Provision a **PostgreSQL** database and an **S3-compatible bucket** (AWS S3, Cloudflare R2, or MinIO).
3. Set production environment variables (see **[SECRETS.md](SECRETS.md)**):
   - `JWT_SIGNING_SECRET`
   - `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`
   - `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET`
   - `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
   - `OPENAI_API_KEY`
4. Set active profile: `SPRING_PROFILES_ACTIVE=prod`.

---

## 4. Connecting the Flutter Client

Run or compile the Flutter application with the Spring Boot backend target:

```powershell
flutter run -d windows `
  --dart-define=FOLIO_BACKEND_MODE=spring `
  --dart-define=FOLIO_BACKEND_BASE_URL=http://127.0.0.1:18080
```

---

## 6. Custom domains (`folio.com.es`)

Canonical production hosts:

| Role | Host |
|------|------|
| Web app (prod) | `https://folio.com.es` |
| Web app (beta) | `https://beta.folio.com.es` |
| API (prod) | `https://api.folio.com.es` |
| API (beta) | `https://api-beta.folio.com.es` |
| WebSocket | `wss://api.folio.com.es/ws/collab` (and beta equivalent) |

### DNS / platform checklist

1. **Railway (API prod + beta):** add custom domains `api.folio.com.es` and `api-beta.folio.com.es`; set CNAME/ALIAS as Railway indicates; update env:
   - Prod: `APP_PUBLIC_BASE_URL=https://api.folio.com.es`, `FOLIO_WEB_BASE_URL=https://folio.com.es`
   - Beta: `APP_PUBLIC_BASE_URL=https://api-beta.folio.com.es`, `FOLIO_WEB_BASE_URL=https://beta.folio.com.es`
2. **Vercel (Flutter web):** add `folio.com.es`, `www.folio.com.es`, `beta.folio.com.es`.
3. **Stripe webhook:** point to `https://api.folio.com.es/api/v1/billing/webhook` (keep legacy URL until cutover).
4. **Resend:** verify `folio.com.es` and prefer `MAIL_FROM=noreply@folio.com.es`.
5. **Spotify / OAuth redirects:** allow `https://folio.com.es/spotify_oauth_callback.html` and beta.
6. Keep legacy `*.minealexgames.com` domains as redirects/aliases until clients update.

Legacy Minealex hosts remain accepted by CORS and client host checks during migration.

---

## 7. API Testing & Postman Collection

- **Swagger UI**: `http://127.0.0.1:18080/swagger-ui/index.html`
- **Postman Collection**: `backend/postman/Folio_Cloud_API.postman_collection.json`
- **Postman Environment**: `backend/postman/Folio_Cloud_Local.postman_environment.json`
