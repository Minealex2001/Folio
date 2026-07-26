# Migración Firebase → Spring Boot

Inventario y plan de migración de todo lo que Folio usa de Firebase hoy, basado en el estado real del repo (`functions/src/index.ts`, `firestore.rules`, `storage.rules`, `pubspec.yaml`, `lib/services/folio_cloud/`).

## 0. Resumen ejecutivo

Folio ya tiene una ventaja de partida importante: **el cliente de escritorio (Windows/Linux) no usa los SDKs nativos de Firebase para las callables** — `cloud_functions` no funciona bien fuera de Android/iOS, así que ya hablan HTTP plano (`Authorization: Bearer <idToken>`) contra las Cloud Functions (ver [FOLIO_CLOUD_BACKEND.md](FOLIO_CLOUD_BACKEND.md) y [folio_cloud_callable.dart](../lib/services/folio_cloud/folio_cloud_callable.dart)). Eso significa que sustituir el backend por Spring Boot es, en gran parte, **cambiar la URL base y el esquema de token**, no reescribir el cliente desde cero.

Lo que sí es trabajo grande:
- Portar ~40 funciones (`onCall`/`onRequest`/`onSchedule`) a controllers Spring.
- Portar las reglas de seguridad de Firestore/Storage (437 líneas combinadas) a lógica de autorización explícita en el service layer — esto es el mayor riesgo de regresión porque hoy es declarativo y "gratis".
- Reemplazar Firestore por una base de datos relacional o documental propia.
- Reemplazar Firebase Auth por un proveedor propio o gestionado (Keycloak/Auth0) que emita JWTs equivalentes.
- Reemplazar Firebase Storage por S3 (o compatible) con URLs firmadas.

## 1. Autenticación (Firebase Auth)

**Uso actual:**
- Login/sesión del cliente Flutter vía `firebase_auth` / `firebase_auth_platform_interface` (con [fork local en `vendor/firebase_auth_platform_interface`](../vendor/firebase_auth_platform_interface) para evitar un crash conocido en Windows — flutter/flutterfire#18210).
- Custom claims / perfil extendido en `users/{uid}` (Firestore), no en los claims del token: `folioStaff`, `folioCloud.active`, `folioCloud.features.*`, `ink`, `stripeCustomerId`.
- Trigger [`onUserCreated`](../functions/src/index.ts:4418) (Auth v1 `auth.user().onCreate`) — crea el doc inicial en `users/{uid}` al registrarse.
- Verificación de ID token en cada callable (`request.auth.uid`).

**Qué migrar:**
- Sustituir por Spring Security + emisión de JWT propia, o delegar en un IdP gestionado (Keycloak / Auth0 / Cognito) si no quieres mantener tú el flujo de password reset, verificación de email, etc.
- El trigger `onUserCreated` se convierte en un paso explícito del endpoint de registro (`POST /auth/register` → crear fila `users` con valores por defecto).
- Cada controller necesita el equivalente de `request.auth.uid`: un filtro/interceptor de Spring Security que valide el JWT y exponga el `uid` en el `SecurityContext`.
- Decisión pendiente: ¿mantienes Firebase Auth solo para auth y migras todo lo demás? Es una opción intermedia razonable a corto plazo (menos trabajo, pero sigues atado a Google para login).

## 2. Base de datos (Firestore → Postgres/Mongo)

**Colecciones detectadas** (por uso real en `functions/src/index.ts` y las rules):

| Colección | Escritura | Propósito |
|---|---|---|
| `users/{uid}` | solo Functions (Admin SDK) | perfil, `folioCloud`, `ink`, `stripeCustomerId`, `billing.stripe`, `billing.microsoftStore` |
| `families/{ownerUid}` | solo Functions | grupo familiar, miembros |
| `collabRooms/{roomId}` | Functions (create) + **cliente directo** (update, con reglas muy específicas) | salas de colaboración en tiempo real, contenido E2E cifrado |
| `collabRooms/{roomId}/media/{mediaId}` | — | metadatos de adjuntos multimedia por sala |
| `collabJoinIndex/{key}` | solo Functions | índice código de invitación → sala |
| `collabJoinAttempts/{uid}` | solo Functions | rate-limit de intentos de unión |
| `publishedPages/{docId}` | **cliente directo** (create/update/delete con condición de plan) | índice de páginas publicadas en la web |
| `communityTemplates/{docId}` | **cliente directo** (con validación de esquema en rules) | catálogo público de plantillas |
| `stripeWebhookEvents/{eventId}` | solo Functions | idempotencia de webhooks Stripe |
| `stripeProcessedCheckouts/{sessionId}` | solo Functions | evita doble crédito de tinta en Checkout |
| `microsoftStoreProcessedPurchases/{docId}` | solo Functions | idempotencia de consumibles MS Store |
| `microsoftStoreProcessedBackupGrants/{docId}` | solo Functions | idempotencia de grants de backup vía Store |
| `folioCloudSubscribers/{uid}` | solo Functions | índice para el job mensual de recarga de tinta |
| `vaultBackupIndex/{...}` | solo Functions | índice de backups por libreta |
| `vaultBackups/{...}` | solo Functions | metadatos de backups (blobs viven en Storage) |
| `items`, `media` | (uso a confirmar en cliente — revisar `folio_firestore_sync.dart`) | posible contenido de usuario sincronizado directo |

**Punto clave:** la mayoría de escrituras pasan por Cloud Functions con Admin SDK (`allow write: if false` en las rules), lo cual es bueno: esa lógica de negocio ya está centralizada en `functions/src/index.ts` y se traduce case por case a service methods de Spring. Las excepciones con **escritura directa desde el cliente** (`collabRooms` update, `publishedPages`, `communityTemplates`) son las que requieren más cuidado: hoy la validación de esas escrituras vive **solo** en las security rules (ver sección 5) y hay que decidir si en Spring pasan a ser también writes directos autenticados (replicando la validación en el controller) o si se fuerzan a pasar por un endpoint dedicado (más seguro, recomendado).

**Elección de motor:** dado que hay documentos con forma variable (`collabRooms` con campos condicionales `e2eV`/`wrappedRoomKey`/`contentCipher`) y listas de miembros (`memberUids`), Postgres con columnas JSONB para los blobs semi-estructurados (contenido cifrado, metadata de features) + tablas normales para lo relacional (users, families, billing) es razonable. MongoDB sería un mapeo más directo documento-a-documento pero pierdes las garantías relacionales que sí usas (families ↔ users, collabRooms ↔ media).

### 2.1 Propuesta de esquema Postgres

Basado en las formas de documento reales que escribe `functions/src/index.ts` (`folioCloud`, `ink`, `billing.stripe`/`billing.microsoftStore`, `collabRooms`, `vaultBackups` como subcolección de `users/{uid}`, etc.).

**Decisión de claves:** usa el **mismo UID string** que hoy asigna Firebase Auth (o el que emita tu nuevo proveedor) como `TEXT PRIMARY KEY` de `users`, en vez de generar UUIDs nuevos. Así migras los datos existentes sin tener que remapear claves foráneas en 15 tablas a la vez — es un `INSERT` directo con el mismo id.

**Simplificación importante respecto a Firestore:** varias colecciones actuales (`folioCloudSubscribers`, `vaultBackupIndex`) existen **solo** porque Firestore no permite consultas agregadas/joins eficientes — son índices de lectura hechos a mano. En Postgres esto desaparece: una columna `active BOOLEAN` con índice en `user_folio_cloud`, o una `SELECT` con `WHERE`/`JOIN`, sustituye a esas colecciones-índice. Se puede prescindir de sus tablas equivalentes y borrar el job que las mantenía sincronizadas.

```sql
-- ============ Usuarios y perfil ============
CREATE TABLE users (
  id                  TEXT PRIMARY KEY,           -- mismo uid que hoy (Firebase o el nuevo IdP)
  email               TEXT NOT NULL,
  display_name        TEXT,
  folio_staff         BOOLEAN NOT NULL DEFAULT FALSE,
  stripe_customer_id  TEXT UNIQUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 1:1 con users — hoy es el objeto `folioCloud` de recomputeEffectiveFolioCloud()
CREATE TABLE user_folio_cloud (
  user_id               TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  subscription_status   TEXT,                      -- 'active' | 'canceled' | ... (espejo de Stripe)
  active                BOOLEAN NOT NULL DEFAULT FALSE,
  subscription_price_id TEXT,
  is_family             BOOLEAN NOT NULL DEFAULT FALSE,
  is_student            BOOLEAN NOT NULL DEFAULT FALSE,
  student_verified      BOOLEAN NOT NULL DEFAULT FALSE,
  family_owner_uid      TEXT REFERENCES users(id),
  family_seats          INT NOT NULL DEFAULT 0,
  features              JSONB NOT NULL DEFAULT '{}', -- {publishWeb, realtimeCollab, backup, cloudAi, ...}
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_user_folio_cloud_active ON user_folio_cloud(active) WHERE active;

-- 1:1 con users — objeto `ink`
CREATE TABLE user_ink (
  user_id            TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  monthly_balance    NUMERIC NOT NULL DEFAULT 0,
  purchased_balance  NUMERIC NOT NULL DEFAULT 0,
  monthly_period_key TEXT,                        -- ej. "2026-07" (Europe/Madrid) para el job mensual
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 1:1 con users — objeto `billing.stripe`
CREATE TABLE user_billing_stripe (
  user_id           TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  subscription_id   TEXT,
  price_id          TEXT,
  family_seats      INT NOT NULL DEFAULT 0,
  student_verified  BOOLEAN NOT NULL DEFAULT FALSE,
  raw               JSONB NOT NULL DEFAULT '{}'    -- resto de campos de Stripe que no merecen columna propia
);

-- 1:1 con users — objeto `billing.microsoftStore`
CREATE TABLE user_billing_microsoft_store (
  user_id                     TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  subscription_active         BOOLEAN NOT NULL DEFAULT FALSE,
  subscription_store_product_id TEXT,
  last_validated_at           TIMESTAMPTZ,
  last_item_count             INT
);

-- ============ Familias ============
CREATE TABLE families (
  owner_uid  TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- sustituye el array `members` + mapa `membersInfo.{uid}` de Firestore
CREATE TABLE family_members (
  family_owner_uid TEXT NOT NULL REFERENCES families(owner_uid) ON DELETE CASCADE,
  member_uid       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  email_snapshot   TEXT,                           -- copia al momento de invitar (por si el email cambia luego)
  display_name_snapshot TEXT,
  joined_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (family_owner_uid, member_uid)
);

-- ============ Colaboración en tiempo real ============
CREATE TABLE collab_rooms (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_uid          TEXT NOT NULL REFERENCES users(id),
  vault_page_id      TEXT NOT NULL,
  join_code_key      TEXT UNIQUE NOT NULL,          -- hash/normalizado del código de invitación
  join_code          TEXT,                          -- solo si aún lo necesitas en claro; valora no guardarlo
  e2e_v              SMALLINT NOT NULL DEFAULT 1,
  content_version    INT NOT NULL DEFAULT 0,
  title              TEXT,                          -- solo salas "legacy" (e2eV=0)
  blocks             JSONB,                          -- solo salas "legacy"
  wrapped_room_key   TEXT,                           -- salas E2E (e2eV=1)
  content_cipher     TEXT,                           -- salas E2E (e2eV=1)
  updated_by         TEXT REFERENCES users(id),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- sustituye `memberUids` (array) + `memberJoinedAt` (mapa) de Firestore
CREATE TABLE collab_room_members (
  room_id    UUID NOT NULL REFERENCES collab_rooms(id) ON DELETE CASCADE,
  member_uid TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, member_uid)
);

-- colabRooms/{roomId}/media/{mediaId}
CREATE TABLE collab_room_media (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id      UUID NOT NULL REFERENCES collab_rooms(id) ON DELETE CASCADE,
  block_id     TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  media_kind   TEXT NOT NULL,
  size_bytes   BIGINT NOT NULL,
  e2e_v        SMALLINT NOT NULL DEFAULT 1,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- collabJoinAttempts — esto es rate-limiting puro; considera Redis (TTL nativo)
-- en vez de una tabla si el volumen crece. Si se queda en Postgres:
CREATE TABLE collab_join_attempts (
  uid              TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  attempt_count    INT NOT NULL DEFAULT 0,
  window_started_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============ Publicación web y plantillas comunitarias ============
CREATE TABLE published_pages (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_uid           TEXT NOT NULL REFERENCES users(id),
  storage_path        TEXT NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE community_templates (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_uid              TEXT NOT NULL REFERENCES users(id),
  name                   TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 280),
  description            TEXT CHECK (char_length(description) <= 4000),
  category               TEXT CHECK (char_length(category) <= 120),
  emoji                  TEXT CHECK (char_length(emoji) <= 32),
  block_count            INT NOT NULL CHECK (block_count BETWEEN 0 AND 50000),
  storage_path           TEXT NOT NULL,
  storage_download_url   TEXT NOT NULL CHECK (char_length(storage_download_url) <= 2048),
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- los CHECK replican 1:1 las validaciones de communityTemplateCreateOk() en firestore.rules:96-119

-- ============ Idempotencia de pagos (ledgers, no "colecciones") ============
CREATE TABLE stripe_webhook_events (
  event_id     TEXT PRIMARY KEY,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE stripe_processed_checkouts (
  session_id   TEXT PRIMARY KEY,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE microsoft_store_processed_purchases (
  id           TEXT PRIMARY KEY,                   -- hash estable uid + línea de compra
  user_id      TEXT NOT NULL REFERENCES users(id),
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE microsoft_store_processed_backup_grants (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id),
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============ Backups de vault (hoy: users/{uid}/vaultBackups/{vaultId}) ============
CREATE TABLE vault_backups (
  user_id                     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vault_id                    TEXT NOT NULL,
  latest_storage_path         TEXT,
  latest_size_bytes           BIGINT NOT NULL DEFAULT 0,
  cloud_pack_restore_wrap_b64 TEXT,                -- blob cifrado en cliente (vaultDek o packKey)
  cloud_pack_restore_wrap_kind TEXT CHECK (cloud_pack_restore_wrap_kind IN ('vaultDek','packKey')),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, vault_id)
);

-- blobs de contenido-direccionado (blobId = sha256) que componen el cloud pack
CREATE TABLE vault_backup_blobs (
  user_id      TEXT NOT NULL,
  vault_id     TEXT NOT NULL,
  blob_id      TEXT NOT NULL CHECK (blob_id ~ '^[0-9a-f]{64}$'),
  storage_path TEXT NOT NULL,
  size_bytes   BIGINT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, vault_id, blob_id),
  FOREIGN KEY (user_id, vault_id) REFERENCES vault_backups(user_id, vault_id) ON DELETE CASCADE
);
-- Nota: `vaultBackupIndex` (Firestore) no necesita tabla propia — es la misma
-- información que `vault_backups`, indexada distinto solo por limitaciones de Firestore.
-- Igual con `folioCloudSubscribers`: sustitúyela por
--   SELECT user_id FROM user_folio_cloud WHERE active AND subscription_price_id IS NOT NULL
-- dentro del job `monthlyInkRefill`.
```

**Sobre `items`/`media`** (uso a confirmar en `folio_firestore_sync.dart`): si resultan ser el contenido real de las libretas/páginas del usuario (no solo metadata), probablemente no quieras normalizarlos en columnas — mantenlos como un blob versionado (JSONB o BYTEA si van cifrados en cliente, con un `content_version` como ya hace `collab_rooms`) en una tabla `vault_items` o similar. Antes de diseñar esa tabla merece la pena revisar exactamente qué sincroniza ese archivo, porque probablemente sea el store principal del contenido de usuario y no una colección secundaria como las demás.

## 3. Cloud Functions → REST Controllers

`functions/src/index.ts` tiene ~4400 líneas y ~40 endpoints. Agrupados por dominio (nombre real de la función entre paréntesis):

### 3.1 Billing / Stripe
- `stripeWebhook` (`onRequest`) — verificación de firma Stripe, idempotencia vía `stripeWebhookEvents`/`stripeProcessedCheckouts`.
- `createCheckoutSession`, `createBillingPortalSession`, `syncFolioCloudSubscriptionFromStripe`.
- → Spring: un `@RestController` de billing + el SDK Java de Stripe; la verificación de firma (`Stripe-Signature` header) es directa con `com.stripe:stripe-java`.

### 3.2 Microsoft Store (IAP de escritorio)
- `validateMicrosoftStoreEntitlements` — llama a la Collections API de Microsoft con token Azure AD, resuelve consumibles/suscripción, idempotencia vía `microsoftStoreProcessedPurchases`.
- → Spring: cliente HTTP a `collections.mp.microsoft.com`, mismas variables (`AZURE_AD_TENANT_ID/CLIENT_ID/CLIENT_SECRET`).

### 3.3 Colaboración en tiempo real
- `createCollabRoom`, `joinCollabRoomByCode`, `prepareCollabMediaUpload`, `commitCollabMediaUpload`, `inviteCollabMember`, `removeCollabMember`, `closeCollabRoom`.
- Nota: esto es solo el control-plane (crear sala, gestionar miembros, autorizar subida de media). El **contenido en vivo** de la sala se sincroniza hoy vía updates directos a Firestore (ver sección 2) — si migras esto de verdad en tiempo real necesitarás WebSockets/STOMP en Spring o un servicio de sync dedicado, no solo REST.

### 3.4 Cloud backup / Vault
- `folioFinalizeCloudPack`, `folioGetLatestCloudPackMeta`, `folioGetCloudPackRestoreWrap`, `folioCheckCloudPackBlobsExist`, `folioGetBackupStorageUsage`, `folioListVaultBackups`, `folioTrimVaultBackupsByBytes`, `folioTrimVaultBackups`, `folioListBackupVaults`, `folioUpsertVaultBackupIndex`, `folioGetLatestVaultBackupMeta`, `folioRecordVaultBackupMeta`.
- Todo el contenido ya viaja cifrado end-to-end desde el cliente (el backend solo gestiona blobs/metadata) — buena noticia, no hay que portar criptografía.

### 3.5 IA
- `folioCloudAiPricing`, `folioCloudAiComplete` (v1, deliberadamente 1st-gen por temas de IAM/429 — ver docs), `folioCloudAiCompleteHttp` (fallback HTTP puro), `folioCloudTranscribeChunk`.
- Usan **OpenAI** directamente: modelo de chat vía `OPENAI_MODEL` (default `gpt-5.4-mini-2026-03-17`) y transcripción vía `OPENAI_TRANSCRIBE_MODEL` (default `gpt-4o-transcribe`; no Whisper API clásica, aunque el código interno aún se refiere a "Whisper segments" por el formato `verbose_json`).
- → Spring: un servicio que llama a la API de OpenAI con el mismo modelo; la lógica de negocio (cobro/reembolso de tinta, límites) se porta 1:1 ya que está en el mismo archivo.

### 3.6 Family sharing
- `inviteFamilyMember`, `removeFamilyMember`, `getFamilyDetails`, `verifyStudentStatus`.

### 3.7 Integraciones / utilidades
- `folioJiraExchangeOAuth` (`onRequest`) — intercambio OAuth con Jira, ver también [`jira_auth_service.dart`](../lib/services/jira/jira_auth_service.dart).
- `folioReportDiagnostic` (`onRequest`) — recepción de diagnósticos del cliente.
- `ensureUserDocExists` (`onCall`) — reparación idempotente del doc de usuario.

### 3.8 Programado
- `monthlyInkRefill` (`onSchedule`) — recarga mensual de tinta el día 1, usa el índice `folioCloudSubscribers`.
- → Spring: `@Scheduled(cron = "...")` o un job en un scheduler externo (Quartz, o simplemente un cron de infraestructura que golpee un endpoint interno).

## 4. Storage (Firebase Storage → S3 o equivalente)

Rutas actuales (de `storage.rules`) y su propósito:

| Ruta | Contenido | Control de acceso |
|---|---|---|
| `users/{uid}/backups/**` | backups cifrados del usuario | dueño + feature `backup` activa |
| `users/{uid}/vaults/{vaultId}/backups/**` | backups por libreta | ídem |
| `users/{uid}/vaults/{vaultId}/cloud-packs/**` | backups incrementales (blobs + snapshots cifrados en cliente) | ídem |
| `published/{uid}/**` | páginas HTML publicadas | lectura pública; escritura dueño + feature `publishWeb` |
| `community-templates/{uid}/{file}.folio-template` | plantillas comunitarias | lectura pública; escritura dueño, límite 1 MB |
| `collab-media-e2e/{roomId}/{mediaId}` | adjuntos multimedia cifrados E2E | miembros de la sala; límite 80 MB; sin delete |

**Qué migrar:**
- S3 (o MinIO si quieres self-host) + URLs presignadas para subida/descarga, replicando el flujo actual de `prepareCollabMediaUpload` (el cliente pide una URL firmada) → `commitCollabMediaUpload` (confirma y registra metadata).
- El check `firestore.get(...)` que las Storage Rules hacen hoy contra `users/{uid}` o `collabRooms/{roomId}` para autorizar (líneas 7-19 y 33-45 de `storage.rules`) se convierte en una consulta normal a tu base de datos dentro del controller antes de emitir la URL firmada.
- Ya hay una capa REST propia hacia Storage en el cliente: [`folio_firebase_storage_rest.dart`](../lib/services/folio_cloud/folio_firebase_storage_rest.dart) — mismo patrón que Firestore, facilita el swap.

## 5. Reglas de seguridad → autorización explícita (el punto más delicado)

`firestore.rules` (327 líneas) y `storage.rules` (110 líneas) hoy hacen gratis, de forma declarativa:
- Ownership checks (`request.auth.uid == resource.data.ownerUid`).
- Validación de esquema en escritura (tipos, tamaños máximos, campos permitidos) — ej. `communityTemplateCreateOk()` en `firestore.rules:96-119`.
- Restricción de qué campos pueden cambiar en un update (`diff(resource.data).changedKeys().hasOnly([...])`) — ej. el update de `collabRooms` distingue entre "sala legacy" y "sala E2E sellada" y solo permite tocar ciertos campos en cada caso (`firestore.rules:162-199`).
- Checks cruzados entre colecciones (leer `collabRooms/{roomId}` para decidir si puedes escribir en `collabRooms/{roomId}/media`, o leer `users/{uid}` desde Storage Rules).

En Spring nada de esto es automático: **cada uno de estos checks se convierte en código explícito** en el controller o service, y hay que tener disciplina para no dejar un endpoint sin la validación equivalente (fácil de olvidar algo, sobre todo las restricciones de "qué campos puede cambiar un update"). Recomendación: escribir tests que repliquen los casos límite que hoy cubren las rules, antes de dar la migración por completa.

## 6. Analytics / Telemetría

- `firebase_analytics` — uso ligero, fácil de sustituir por tu propio pipeline: ya existe [`folio_telemetry.dart`](../lib/services/folio_telemetry.dart) y un [dashboard propio](../lib/features/telemetry_dashboard/telemetry_dashboard_page.dart), y una function `telemetry.ts` separada. Probablemente ya no dependes de Analytics para nada crítico — confirmar antes de decidir si lo quitas del todo o lo dejas en paralelo solo para métricas de producto/marketing.

## 7. Cliente Flutter — qué cambia

- Quitar `firebase_core`, `firebase_auth*`, `firebase_storage`, `firebase_analytics` de `pubspec.yaml` una vez migrado todo, y borrar [`firebase_options.dart`](../lib/firebase_options.dart).
- El patrón ya usado en `folio_firestore_rest.dart` / `folio_firebase_storage_rest.dart` / `folio_cloud_callable.dart` (HTTP + Bearer token) se mantiene casi igual — cambia el host, el formato exacto de error (`{error:{status,message}}` de las callables vs. el que definas tú) y el esquema de token (ID token de Firebase vs. tu propio JWT).
- El login pasa de `firebase_auth` a lo que decidas (llamadas HTTP a tu backend de auth, o SDK del IdP elegido).

## 8. Fases recomendadas

1. **Auth primero, en paralelo**: monta el servicio de auth propio (o IdP gestionado) emitiendo JWT compatibles con `Authorization: Bearer`, sin tocar nada más. El cliente puede convivir con ambos backends brevemente si hace falta.
2. **Billing y Cloud Functions "de control"** (secciones 3.1–3.2, 3.6–3.8): son puros endpoints request/response, sin necesidad de tiempo real, y ya están muy autocontenidos en `index.ts`.
3. **Storage**: migrar a S3 detrás de la misma interfaz REST que ya usa el cliente.
4. **Firestore → tu BD**: empezar por las colecciones solo-Functions (más fáciles, sin lógica de rules que replicar) y dejar para el final `collabRooms`/`publishedPages`/`communityTemplates` (las de escritura directa desde cliente, que exigen portar las rules).
5. **Tiempo real de colaboración**: si quieres mantener sync en vivo entre miembros de una sala, aquí es donde necesitas WebSockets/STOMP o un servicio de sync propio — no hay atajo REST para esto.
6. **IA**: trivial una vez migrado el resto, es solo un proxy a OpenAI con lógica de cobro de tinta.

## 9. Riesgos a vigilar

- **Regresión de seguridad silenciosa**: perder una de las validaciones de las rules (sección 5) no rompe nada visible hasta que alguien la explota. Escribir tests explícitos de autorización antes de dar por migrada cada colección.
- **Idempotencia de webhooks**: Stripe y Microsoft Store reintentan; las tablas `stripeWebhookEvents`/`stripeProcessedCheckouts`/`microsoftStoreProcessedPurchases` existen justo para eso — no simplificar esa parte al portarla.
- **IAM de invocación pública** (Cloud Run `allUsers` + `roles/run.invoker`) es un problema específico de Firebase Functions v2 que desaparece con Spring Boot — una menos, pero confirma que el nuevo backend no imponga restricciones equivalentes por defecto en tu plataforma de despliegue.
- **Sync en tiempo real de `collabRooms`**: es la pieza que menos se parece a "un CRUD"; conviene diseñarla aparte en vez de forzarla a encajar en el resto del plan REST.
