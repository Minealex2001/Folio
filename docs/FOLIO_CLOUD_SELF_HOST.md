# Folio Cloud — self-host con Docker

Cómo hostear tu propio Folio Cloud (API Spring Boot + Postgres + object storage) con Docker Compose. Pensado para instalaciones open source / on-prem.

El código de la API vive en el repo GitHub **[Folio-Backend](https://github.com/Minealex2001/Folio-Backend)** y en este monorepo como **submodule** `backend/`. Tras clonar Folio: `git submodule update --init --recursive`.

Ver también: [backend/README.md](../backend/README.md) (incluye sección Railway), secretos en [FOLIO_CLOUD_SECRETS.md](FOLIO_CLOUD_SECRETS.md), migración en [MIGRACION_SPRINGBOOT.md](MIGRACION_SPRINGBOOT.md).

## Requisitos

- Docker Engine + Docker Compose v2
- ~2 GB RAM libres para el stack (build Maven de la imagen puede necesitar más en la primera compilación)

## Secretos

El contenedor `api` carga **`backend/.env`** (vía `env_file` de Compose). **No** lee `functions/.env`.

Si ya tienes Stripe/OpenAI/etc. en Cloud Functions, copia las mismas variables a `backend/.env` (nombres idénticos: `STRIPE_SECRET_KEY`, `STRIPE_PRICE_*`, …) y recrea el API:

```powershell
docker compose -f backend/docker-compose.yml up -d --build api
```

Sin `STRIPE_SECRET_KEY` el checkout responde `failed-precondition: Stripe not configured on server`.

### Admin / QA sin Stripe

Para probar Folio Cloud sin pagar:

1. En `backend/.env`: `FOLIO_ADMIN_API_KEY=dev-admin-change-me` (cámbialo).
2. Recrea el API: `docker compose up -d --build api`.
3. Tras registrar un usuario:

```powershell
curl -X POST http://127.0.0.1:18080/api/v1/admin/entitlements/grant-cloud `
  -H "Content-Type: application/json" `
  -H "X-Folio-Admin-Key: dev-admin-change-me" `
  -d "{\"email\":\"tu@email.com\",\"alsoStaff\":true,\"inkDrops\":1000}"
```

También en Postman → carpeta **Admin (QA)**. Detalle en [FEATURES.md](FEATURES.md) (sección Admin / QA).

## Arranque rápido

Desde `backend/`:

```powershell
Copy-Item .env.example .env
# Edita al menos JWT_SIGNING_SECRET antes de exponer la instancia
docker compose up -d --build
```

Desde la raíz del repo:

```powershell
docker compose -f backend/docker-compose.yml --env-file backend/.env up -d --build
```

Comprueba:

```powershell
curl http://127.0.0.1:18080/api/v1/health
# → {"status":"ok"}
```

Servicios:

| Servicio | Puerto host | Notas |
|---|---|---|
| `api` | **18080** (→8080 contenedor) | Spring Boot, perfil `docker`. Configurable con `API_HOST_PORT` |
| `postgres` | 5432 | Volumen `folio_pg_data` |
| `minio` | 9000 / 9001 | API S3 + consola; volumen `folio_minio_data` |
| `mailpit` | 1025 / 8025 | Solo desarrollo / prueba de emails |

**Windows:** no uses `http://localhost:8080`. En muchos equipos `127.0.0.1:8080` lo ocupa el remote debugging CEF/Cursor; Dart resuelve `localhost` a IPv4 y el cliente ve 404 en rutas de Folio. Preferir `http://127.0.0.1:18080`.

## Cliente Flutter

Con Fase 29 (dual-mode), apunta al API self-host:

```powershell
flutter run -d windows `
  --dart-define=FOLIO_BACKEND_MODE=spring `
  --dart-define=FOLIO_BACKEND_BASE_URL=http://127.0.0.1:18080
```

Si el API está en otra máquina o detrás de un proxy, usa esa URL (sin barra final). El WebSocket de collab se deriva automáticamente (`ws`/`wss` + `/ws/collab`).

## Perfil Spring `docker`

`application-docker.yml` fija por defecto:

- JDBC: `jdbc:postgresql://postgres:5432/folio`
- MinIO: `http://minio:9000`
- SMTP: `mailpit:1025`

El `docker-compose.yml` fuerza esas URLs en el servicio `api` aunque `.env` tenga `localhost` (útil para el flujo Maven en el host).

## Desarrollo sin contenedor `api`

Sigue válido el flujo anterior:

```powershell
docker compose -f backend/docker-compose.yml up -d postgres minio mailpit
mvn -f backend/pom.xml spring-boot:run
```

Perfil por defecto: `dev` (`application-dev.yml` → localhost).

## Producción (checklist breve)

1. **Secretos**: `JWT_SIGNING_SECRET` largo y aleatorio; cambia `POSTGRES_PASSWORD`, `S3_ACCESS_KEY` / `S3_SECRET_KEY`.
2. **Volúmenes**: no borres `folio_pg_data` / `folio_minio_data` en `docker compose down -v`.
3. **Correo**: sustituye Mailpit por SMTP real; no publiques `:8025` ni dependas del servicio `mailpit`.
4. **TLS**: pon un reverse proxy (Caddy/nginx/Traefik) delante del puerto del API (`API_HOST_PORT`, por defecto 18080) y alinea `APP_PUBLIC_BASE_URL`.
5. **Integraciones opcionales**: Stripe, OpenAI, Slack, etc. solo si las necesitas — ver `.env.example` y [FOLIO_CLOUD_SECRETS.md](FOLIO_CLOUD_SECRETS.md).
6. **Object storage**: puedes apuntar `S3_*` a un S3 real / R2 / etc. y omitir MinIO.

## Postman (explorar la API)

Tras levantar el stack, importa en Postman:

- [`backend/postman/Folio_Cloud_API.postman_collection.json`](../backend/postman/Folio_Cloud_API.postman_collection.json)
- [`backend/postman/Folio_Cloud_Local.postman_environment.json`](../backend/postman/Folio_Cloud_Local.postman_environment.json) (`baseUrl=http://127.0.0.1:18080`)

Orden sugerido: **Auth → Login** (guarda tokens) → **Account → Me**. Detalle en [`backend/README.md`](../backend/README.md) § Postman. Swagger UI: `http://127.0.0.1:18080/swagger-ui/index.html`.

## Verificación Compose

```powershell
docker compose -f backend/docker-compose.yml config
```
