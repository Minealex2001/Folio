# Folio Backend (Spring Boot)

API REST que sustituye gradualmente Firebase Auth / Firestore / Cloud Functions.

Guía self-host (stack completo en Docker): [docs/FOLIO_CLOUD_SELF_HOST.md](../docs/FOLIO_CLOUD_SELF_HOST.md).

## Requisitos

- Java 21+ (solo si corres la API fuera de Docker)
- Maven 3.9+ (idem)
- Docker / Docker Compose (Postgres, MinIO, Mailpit; opcionalmente la API)

## Self-host: stack completo en Docker

Un solo comando levanta API + Postgres + MinIO + Mailpit:

```powershell
cd backend
Copy-Item .env.example .env   # edita JWT_SIGNING_SECRET y secretos
docker compose up -d --build
```

- Health: http://127.0.0.1:18080/api/v1/health
- Swagger UI: http://127.0.0.1:18080/swagger-ui/index.html
- Collab STOMP: `ws://127.0.0.1:18080/ws/collab`
- Mailpit UI: http://localhost:8025
- MinIO console: http://localhost:9001
- Postman: colección + environment en [`postman/`](postman/) (ver abajo)

El API se publica en el host como **18080→8080** (`API_HOST_PORT`) para no chocar en Windows con el remote debugging CEF/Cursor en `127.0.0.1:8080` (Dart resuelve `localhost` a IPv4 y acababa hablando con el debugger → HTTP 404 en `/auth/register`).

El servicio `api` usa el perfil Spring `docker` (`application-docker.yml`) y resuelve Postgres/MinIO/Mailpit por hostname interno del compose.

### Cliente Flutter

Con el cutover Fase 29, apunta el cliente al API self-host:

```powershell
flutter run -d windows `
  --dart-define=FOLIO_BACKEND_MODE=spring `
  --dart-define=FOLIO_BACKEND_BASE_URL=http://127.0.0.1:18080
```

Usa `127.0.0.1` (no `localhost`) en Windows. (`FOLIO_BACKEND_BASE_URL` es el define actual; no uses un nombre inventado tipo `FOLIO_SPRING_BASE_URL`.)

### Notas de producción

- Cambia `JWT_SIGNING_SECRET`, contraseñas de Postgres/MinIO y cualquier clave de integración en `.env`.
- Los volúmenes `folio_pg_data` / `folio_minio_data` ya son persistentes.
- **No uses Mailpit en producción**: configura SMTP real (`SPRING_MAIL_HOST` / puerto / auth) y quita o no publiques el servicio `mailpit`.
- Expón el puerto del API (o un reverse proxy TLS) y pon `APP_PUBLIC_BASE_URL` a la URL pública que verán los usuarios en los emails.

Detalle: [docs/FOLIO_CLOUD_SELF_HOST.md](../docs/FOLIO_CLOUD_SELF_HOST.md).

## Arranque local (desarrollo: Maven + infra Docker)

Flujo habitual de desarrollo: solo infra en Compose, API con Maven en el host.

```powershell
# 1. Infraestructura
docker compose -f backend/docker-compose.yml up -d postgres minio mailpit

# 2. Aplicación (perfil dev por defecto — URLs localhost)
mvn -f backend/pom.xml spring-boot:run
```

Copia `backend/.env.example` → `backend/.env` si quieres sobrescribir secretos (o exporta las variables en el shell). Las URLs de `.env.example` apuntan a `localhost` para este flujo.

## Postman

Colección v2.1 de todos los endpoints REST (`/api/v1/...`) más una nota STOMP de collab:

| Archivo | Uso |
|---|---|
| [`postman/Folio_Cloud_API.postman_collection.json`](postman/Folio_Cloud_API.postman_collection.json) | Colección completa por dominio |
| [`postman/Folio_Cloud_Local.postman_environment.json`](postman/Folio_Cloud_Local.postman_environment.json) | Environment local (`baseUrl`, tokens, email/password) |

**Importar en Postman:** File → Import → selecciona ambos JSON (o arrástralos). Elige el environment **Folio Cloud Local**.

**Flujo auth:** Auth → Register (opcional) → Login (el script de test guarda `accessToken` / `refreshToken`) → Account → Me → Auth → Refresh.

**Admin / QA (sin Stripe):** carpeta **Admin (QA)** — header `X-Folio-Admin-Key` = variable `adminApiKey` (debe coincidir con `FOLIO_ADMIN_API_KEY` en `.env`). `Grant Folio Cloud` activa entitlements de pago sin Checkout.

Webhooks Stripe y comandos Slack/Teams van como requests públicos con headers de firma *placeholder* (no verifican en local sin secretos reales). El handshake STOMP está documentado en la carpeta **WebSocket STOMP (Collab)**; Postman no sustituye un cliente STOMP completo.

Para regenerar tras cambios de controllers: `python backend/postman/generate_collection.py`.

## Tests

```powershell
mvn -f backend/pom.xml test
```

Los tests de integración usan Testcontainers (Postgres). Si el cliente Java de Testcontainers no puede hablar con Docker Desktop (issue conocido en algunos builds de Windows), caen automáticamente a `docker compose up -d postgres` en `localhost:5432`.
