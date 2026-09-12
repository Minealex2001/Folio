# Folio Cloud — Secrets & Environment Variables

Folio is open-source. Secret keys, database passwords, JWT signing tokens, and private API keys must never be committed to Git.

---

## 1. Secrets Policy

### Strict Exclusion Rules

The following sensitive variables must only exist in `.env` files (which are in `.gitignore`) or server system environment settings:

| Category | Secret Variables | Scope / Location |
|----------|------------------|------------------|
| **JWT Authentication** | `JWT_SIGNING_SECRET` | `backend/.env` / Cloud Host |
| **PostgreSQL Database** | `POSTGRES_PASSWORD`, `SPRING_DATASOURCE_PASSWORD` | `backend/.env` / Host Envs |
| **S3 Object Storage** | `S3_ACCESS_KEY`, `S3_SECRET_KEY` | `backend/.env` / Host Envs |
| **Stripe Payments** | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` | `backend/.env` / Host Envs |
| **AI Inference Provider** | `OPENAI_API_KEY`, `OPENAI_BASE_URL` | `backend/.env` / Host Envs |
| **Admin Controls** | `FOLIO_ADMIN_API_KEY` | `backend/.env` / Host Envs |

---

## 2. Spring Boot Environment Template (`backend/.env`)

Copy `backend/.env.example` to `backend/.env` and update the values for your environment:

```env
# ============ JWT Auth ============
JWT_SIGNING_SECRET=your-long-random-secret-key-at-least-32-chars-long

# ============ PostgreSQL Database ============
POSTGRES_DB=folio
POSTGRES_USER=folio
POSTGRES_PASSWORD=folio_secure_password

# ============ Object Storage (MinIO / S3) ============
S3_ENDPOINT=http://minio:9000
S3_ACCESS_KEY=folio_minio_access_key
S3_SECRET_KEY=folio_minio_secret_key
S3_BUCKET=folio-storage

# ============ Stripe Payment Processing ============
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_FOLIO_CLOUD_MONTHLY=price_...
STRIPE_PRICE_INK_SMALL=price_...
STRIPE_PRICE_INK_MEDIUM=price_...
STRIPE_PRICE_INK_LARGE=price_...

# ============ Quill Cloud AI Operations ============
OPENAI_API_KEY=sk-proj-...
OPENAI_MODEL=gpt-5.4-mini-2026-03-17
OPENAI_TRANSCRIBE_MODEL=gpt-4o-transcribe
OPENAI_BASE_URL=https://api.openai.com/v1

# ============ Admin Key (QA / Dev) ============
FOLIO_ADMIN_API_KEY=dev-admin-change-me
```

---

## 3. Developing Without Backend Secrets

You do **not** need backend secrets or remote services to run or develop the main Folio desktop app:

```powershell
flutter pub get
flutter run -d windows
```

The core editor, encrypted vault storage, local AI (Ollama / LM Studio), and peer device sync operate completely offline without a backend.
