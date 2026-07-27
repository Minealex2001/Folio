#!/usr/bin/env python3
"""Generate Folio Cloud Postman Collection v2.1 from endpoint inventory."""

from __future__ import annotations

import json
import uuid
from pathlib import Path

OUT = Path(__file__).resolve().parent


def uid() -> str:
    return str(uuid.uuid4())


def bearer_header() -> dict:
    return {
        "key": "Authorization",
        "value": "Bearer {{accessToken}}",
        "type": "text",
    }


def json_header() -> dict:
    return {"key": "Content-Type", "value": "application/json", "type": "text"}


def req(
    name: str,
    method: str,
    path: str,
    *,
    auth: bool = True,
    body: object | None = None,
    description: str = "",
    headers: list[dict] | None = None,
    query: list[dict] | None = None,
    raw_mode: str = "json",
    events: list | None = None,
    urlencoded: list[dict] | None = None,
) -> dict:
    """Build a Postman request item. path is relative to {{baseUrl}} (may include query)."""
    path_only = path.split("?")[0]
    segments = [s for s in path_only.strip("/").split("/") if s]
    url: dict = {
        "raw": "{{baseUrl}}" + (path if path.startswith("/") else "/" + path),
        "host": ["{{baseUrl}}"],
        "path": segments,
    }
    if query:
        url["query"] = query

    hdrs: list[dict] = []
    if auth:
        hdrs.append(bearer_header())
    if headers:
        hdrs.extend(headers)
    elif body is not None and urlencoded is None:
        hdrs.append(json_header())

    request: dict = {
        "method": method.upper(),
        "header": hdrs,
        "url": url,
        "description": description,
    }

    if urlencoded is not None:
        request["body"] = {
            "mode": "urlencoded",
            "urlencoded": urlencoded,
        }
        # ensure form content-type if not set
        if not any(h.get("key", "").lower() == "content-type" for h in hdrs):
            hdrs.append(
                {
                    "key": "Content-Type",
                    "value": "application/x-www-form-urlencoded",
                    "type": "text",
                }
            )
    elif body is not None:
        if isinstance(body, str):
            raw = body
        else:
            raw = json.dumps(body, indent=2, ensure_ascii=False)
        request["body"] = {
            "mode": "raw",
            "raw": raw,
            "options": {"raw": {"language": raw_mode}},
        }

    item: dict = {"name": name, "request": request, "response": []}
    if events:
        item["event"] = events
    return item


def folder(name: str, description: str, items: list) -> dict:
    return {
        "name": name,
        "description": description,
        "item": items,
    }


LOGIN_TEST_SCRIPT = """\
const json = pm.response.json();
if (json.accessToken) {
  pm.collectionVariables.set('accessToken', json.accessToken);
  pm.environment.set('accessToken', json.accessToken);
}
if (json.refreshToken) {
  pm.collectionVariables.set('refreshToken', json.refreshToken);
  pm.environment.set('refreshToken', json.refreshToken);
}
pm.test('Login returns tokens', function () {
  pm.expect(json.accessToken).to.be.a('string').and.not.empty;
  pm.expect(json.refreshToken).to.be.a('string').and.not.empty;
});
"""

REFRESH_TEST_SCRIPT = """\
const json = pm.response.json();
if (json.accessToken) {
  pm.collectionVariables.set('accessToken', json.accessToken);
  pm.environment.set('accessToken', json.accessToken);
}
if (json.refreshToken) {
  pm.collectionVariables.set('refreshToken', json.refreshToken);
  pm.environment.set('refreshToken', json.refreshToken);
}
pm.test('Refresh rotates tokens', function () {
  pm.expect(json.accessToken).to.be.a('string').and.not.empty;
});
"""


def test_event(script: str) -> dict:
    return {
        "listen": "test",
        "script": {
            "type": "text/javascript",
            "exec": script.splitlines(),
        },
    }


def build() -> dict:
    health = folder(
        "Health",
        "Health check público (sin auth).",
        [
            req(
                "Health",
                "GET",
                "/api/v1/health",
                auth=False,
                description="Comprueba que la API está viva. Respuesta esperada: `{\"status\":\"ok\"}`.",
            )
        ],
    )

    auth = folder(
        "Auth",
        "Registro, login JWT, refresh, verificación de email y reset de contraseña.\n\n"
        "**Flujo recomendado:** Register → Login (guarda tokens) → Account/me → Refresh.",
        [
            req(
                "Register",
                "POST",
                "/api/v1/auth/register",
                auth=False,
                body={
                    "email": "{{email}}",
                    "password": "{{password}}",
                    "displayName": "Postman Tester",
                },
                description="Crea usuario (Argon2id). Público. Envía email de verificación (Mailpit en local).",
            ),
            req(
                "Login",
                "POST",
                "/api/v1/auth/login",
                auth=False,
                body={"email": "{{email}}", "password": "{{password}}"},
                description="Devuelve accessToken + refreshToken. El script de test guarda ambos en variables de colección y environment.",
                events=[test_event(LOGIN_TEST_SCRIPT)],
            ),
            req(
                "Refresh",
                "POST",
                "/api/v1/auth/refresh",
                auth=False,
                body={"refreshToken": "{{refreshToken}}"},
                description="Rota el refresh token. Público. Guarda los nuevos tokens.",
                events=[test_event(REFRESH_TEST_SCRIPT)],
            ),
            req(
                "Logout",
                "POST",
                "/api/v1/auth/logout",
                body={"refreshToken": "{{refreshToken}}"},
                description="Revoca el refresh token. Requiere Bearer access token.",
            ),
            req(
                "Verify email",
                "POST",
                "/api/v1/auth/verify-email",
                auth=False,
                body={"token": "{{emailVerificationToken}}"},
                description="Público. Token del enlace de verificación (Mailpit).",
            ),
            req(
                "Resend verification",
                "POST",
                "/api/v1/auth/resend-verification",
                description="Reenvía email de verificación. Requiere Bearer. Sin body.",
            ),
            req(
                "Forgot password",
                "POST",
                "/api/v1/auth/forgot-password",
                auth=False,
                body={"email": "{{email}}"},
                description="Público. Envía email con token de reset.",
            ),
            req(
                "Reset password",
                "POST",
                "/api/v1/auth/reset-password",
                auth=False,
                body={
                    "token": "{{passwordResetToken}}",
                    "newPassword": "NewSecurePass123!",
                },
                description="Público. Cambia contraseña y revoca todos los refresh tokens.",
            ),
        ],
    )

    account = folder(
        "Account",
        "Perfil, entitlements Folio Cloud, borrado programado y export GDPR.",
        [
            req(
                "Me",
                "GET",
                "/api/v1/account/me",
                description="Perfil + folioCloud + ink. Tras Login, usa este endpoint para validar el token.",
            ),
            req(
                "Ensure",
                "POST",
                "/api/v1/account/ensure",
                description="Idempotente: asegura filas de perfil/cloud/ink (puerto de ensureUserDocExists).",
            ),
            req(
                "Update display name",
                "PATCH",
                "/api/v1/account/display-name",
                body={"displayName": "Nuevo Nombre"},
                description="Máx. 80 caracteres; propaga a familia si aplica.",
            ),
            req(
                "Request deletion",
                "POST",
                "/api/v1/account/deletion/request",
                description="Programa borrado de cuenta. Sin body.",
            ),
            req(
                "Cancel deletion",
                "POST",
                "/api/v1/account/deletion/cancel",
                description="Cancela borrado programado. Sin body.",
            ),
            req(
                "Export",
                "GET",
                "/api/v1/account/export",
                description="Export de datos de cuenta (GDPR-style).",
            ),
        ],
    )

    users = folder(
        "Users",
        "Endpoint legacy/compat de identidad mínima.",
        [
            req(
                "Users me",
                "GET",
                "/api/v1/users/me",
                description="Identidad mínima del usuario autenticado (compat).",
            )
        ],
    )

    admin_key = {
        "key": "X-Folio-Admin-Key",
        "value": "{{adminApiKey}}",
        "type": "text",
    }
    admin = folder(
        "Admin (QA)",
        "Pruebas locales / self-host **sin pagar Stripe**.\n\n"
        "Auth: header `X-Folio-Admin-Key` = `FOLIO_ADMIN_API_KEY` **o** JWT de usuario `folioStaff`.\n"
        "`grant-cloud` pone `admin_override` (sobrevive a recompute) + features completas.",
        [
            req(
                "Lookup user",
                "POST",
                "/api/v1/admin/users/lookup",
                auth=False,
                headers=[admin_key, json_header()],
                body={"email": "{{email}}"},
                description="Snapshot de cuenta por email o uid.",
            ),
            req(
                "Grant Folio Cloud (no Stripe)",
                "POST",
                "/api/v1/admin/entitlements/grant-cloud",
                auth=False,
                headers=[admin_key, json_header()],
                body={
                    "email": "{{email}}",
                    "alsoStaff": True,
                    "inkDrops": 1000,
                },
                description="Activa Cloud completo + opcional staff + tinta comprada.",
            ),
            req(
                "Revoke Folio Cloud grant",
                "POST",
                "/api/v1/admin/entitlements/revoke-cloud",
                auth=False,
                headers=[admin_key, json_header()],
                body={"email": "{{email}}"},
                description="Quita admin_override y recalcula entitlements (vuelve a free/Stripe).",
            ),
            req(
                "Grant ink",
                "POST",
                "/api/v1/admin/ink/grant",
                auth=False,
                headers=[admin_key, json_header()],
                body={"email": "{{email}}", "inkDrops": 1000},
                description="Suma tinta purchasedBalance (default 1000).",
            ),
            req(
                "Set folioStaff",
                "POST",
                "/api/v1/admin/staff",
                auth=False,
                headers=[admin_key, json_header()],
                body={"email": "{{email}}", "staff": True},
                description="Marca/desmarca folioStaff (cuota backup ilimitada, etc.).",
            ),
        ],
    )

    billing = folder(
        "Billing",
        "Stripe Checkout/Portal/sync/webhook y Microsoft Store IAP.\n\n"
        "`kind` de checkout: folio_cloud_monthly | folio_family_monthly | folio_student_monthly | "
        "ink_small | ink_medium | ink_large | backup_storage_pack_small|medium|large.",
        [
            req(
                "Create checkout session",
                "POST",
                "/api/v1/billing/checkout-session",
                body={"kind": "folio_cloud_monthly", "debug": True},
                description="Crea sesión Stripe Checkout. Requiere Bearer.",
            ),
            req(
                "Create portal session",
                "POST",
                "/api/v1/billing/portal-session",
                body={"debug": True},
                description="Portal de cliente Stripe.",
            ),
            req(
                "Sync billing",
                "POST",
                "/api/v1/billing/sync",
                body={"debug": True},
                description="Sincroniza estado de suscripción desde Stripe.",
            ),
            req(
                "Stripe webhook",
                "POST",
                "/api/v1/billing/webhook",
                auth=False,
                body={
                    "id": "evt_placeholder",
                    "object": "event",
                    "type": "checkout.session.completed",
                    "data": {"object": {"id": "cs_test_placeholder"}},
                },
                headers=[
                    json_header(),
                    {
                        "key": "Stripe-Signature",
                        "value": "t={{stripeSigTimestamp}},v1={{stripeSigPlaceholder}}",
                        "type": "text",
                    },
                ],
                description=(
                    "**Público** con verificación propia. Header `Stripe-Signature` obligatorio "
                    "(formato `t=...,v1=...`). El body debe ser el payload raw firmado por Stripe; "
                    "este ejemplo es placeholder y fallará la verificación de firma en local."
                ),
            ),
            req(
                "Microsoft Store validate",
                "POST",
                "/api/v1/billing/microsoft-store/validate",
                body={"collectionsId": "{{msStoreCollectionsId}}"},
                description="Valida compras Microsoft Store (Azure AD + Collections API).",
            ),
        ],
    )

    family = folder(
        "Family",
        "Plan familia: invitar/quitar miembros y verificación estudiante.",
        [
            req(
                "Invite member",
                "POST",
                "/api/v1/family/invite",
                body={"email": "member@example.com", "debug": True},
                description="Invita miembro al plan familia.",
            ),
            req(
                "Remove member",
                "POST",
                "/api/v1/family/remove",
                body={"memberUid": "{{memberUid}}", "debug": True},
                description="Quita miembro por UID.",
            ),
            req(
                "Family details",
                "GET",
                "/api/v1/family/details",
                description="Lista miembros e info de familia.",
            ),
            req(
                "Verify student",
                "POST",
                "/api/v1/family/verify-student",
                body={"email": "student@university.edu"},
                description="Verifica elegibilidad estudiante por dominio de email.",
            ),
        ],
    )

    vault_id = {"vaultId": "{{vaultId}}"}

    vault_backups = folder(
        "Vault Backups",
        "Cloud-pack incremental, índices legacy, trim y uso de almacenamiento.",
        [
            req(
                "Cloud pack finalize",
                "POST",
                "/api/v1/vault/backups/cloud-pack/finalize",
                body={
                    "vaultId": "{{vaultId}}",
                    "snapshotStoragePath": "vaults/{{vaultId}}/cloud-pack/snapshot.bin",
                    "snapshotSizeBytes": 1024,
                    "contentFingerprint": "fp-example",
                    "oldSnapshotStoragePath": None,
                    "oldSnapshotSizeBytes": None,
                    "newBlobs": [{"blobId": "blob-1", "sizeBytes": 256}],
                    "deleteBlobs": [],
                    "cloudPackRestoreWrapB64": "d3JhcC1leGFtcGxl",
                    "cloudPackRestoreWrapKind": "account",
                },
                description="Finaliza subida de cloud-pack incremental.",
            ),
            req(
                "Cloud pack latest meta",
                "POST",
                "/api/v1/vault/backups/cloud-pack/latest-meta",
                body=vault_id,
                description="Meta del último cloud-pack.",
            ),
            req(
                "Cloud pack restore wrap",
                "POST",
                "/api/v1/vault/backups/cloud-pack/restore-wrap",
                body=vault_id,
                description="Obtiene envoltorio de restauración del cloud-pack.",
            ),
            req(
                "Cloud pack blobs exist",
                "POST",
                "/api/v1/vault/backups/cloud-pack/blobs-exist",
                body={"vaultId": "{{vaultId}}", "blobIds": ["blob-1", "blob-2"]},
                description="Comprueba existencia de blobs en storage.",
            ),
            req(
                "Usage",
                "POST",
                "/api/v1/vault/backups/usage",
                description="Uso de almacenamiento de backups. Sin body.",
            ),
            req(
                "List backups",
                "POST",
                "/api/v1/vault/backups/list",
                body=vault_id,
                description="Lista backups de una libreta.",
            ),
            req(
                "Cloud pack delete",
                "POST",
                "/api/v1/vault/backups/cloud-pack/delete",
                body=vault_id,
                description="Borra cloud-pack de la libreta.",
            ),
            req(
                "Legacy delete",
                "POST",
                "/api/v1/vault/backups/legacy/delete",
                body=vault_id,
                description="Borra backups legacy (ZIP/TAR).",
            ),
            req(
                "Trim by bytes",
                "POST",
                "/api/v1/vault/backups/trim-by-bytes",
                body={"targetUsedBytes": 1073741824},
                description="Recorta backups hasta un tamaño objetivo.",
            ),
            req(
                "Trim keep latest",
                "POST",
                "/api/v1/vault/backups/trim",
                body={"keepLatestPerVault": 3},
                description="Conserva N backups más recientes por vault.",
            ),
            req(
                "List vaults with backups",
                "POST",
                "/api/v1/vault/backups/vaults",
                description="Lista vaultIds con presencia en backups. Sin body.",
            ),
            req(
                "Index upsert",
                "POST",
                "/api/v1/vault/backups/index/upsert",
                body={
                    "vaultId": "{{vaultId}}",
                    "latestStoragePath": "vaults/{{vaultId}}/legacy/latest.zip",
                    "latestSizeBytes": 2048,
                    "contentFingerprint": "fp-legacy",
                },
                description="Upsert del índice de backup legacy.",
            ),
            req(
                "Latest meta",
                "POST",
                "/api/v1/vault/backups/latest-meta",
                body=vault_id,
                description="Meta del último backup (índice).",
            ),
            req(
                "Record meta",
                "POST",
                "/api/v1/vault/backups/record-meta",
                body={
                    "vaultId": "{{vaultId}}",
                    "storagePath": "vaults/{{vaultId}}/legacy/snap.zip",
                    "sizeBytes": 4096,
                    "contentFingerprint": "fp-record",
                },
                description="Registra meta de un backup individual.",
            ),
        ],
    )

    device_sync = folder(
        "Device Sync",
        "Sincronización multi-dispositivo vía packs en object storage.",
        [
            req(
                "Meta",
                "POST",
                "/api/v1/vault/device-sync/meta",
                body=vault_id,
                description="Meta del pack de device-sync.",
            ),
            req(
                "Finalize",
                "POST",
                "/api/v1/vault/device-sync/finalize",
                body={
                    "vaultId": "{{vaultId}}",
                    "syncFormatVersion": 1,
                    "contentFingerprint": "fp-sync",
                    "packStoragePath": "vaults/{{vaultId}}/device-sync/pack.bin",
                    "packSizeBytes": 8192,
                    "manifestStoragePath": "vaults/{{vaultId}}/device-sync/manifest.json",
                    "manifestSizeBytes": 128,
                    "oldPackStoragePath": None,
                    "oldPackSizeBytes": None,
                    "oldManifestStoragePath": None,
                    "oldManifestSizeBytes": None,
                    "newBlobs": [{"blobId": "b1", "sizeBytes": 100}],
                    "deleteBlobs": [],
                    "deviceId": "{{deviceId}}",
                    "deviceName": "Postman PC",
                    "vaultMode": "encrypted",
                    "packKeyKind": "account",
                    "dekAccountWrapB64": "ZGVrLXdyYXA=",
                },
                description="Finaliza subida de pack de sync.",
            ),
            req(
                "List vaults",
                "POST",
                "/api/v1/vault/device-sync/vaults",
                description="Vaults con device-sync. Sin body.",
            ),
            req(
                "Ensure plain secret",
                "POST",
                "/api/v1/vault/device-sync/plain-secret/ensure",
                body=vault_id,
                description="Asegura secreto para libretas en claro.",
            ),
        ],
    )

    profiles = folder(
        "Profiles",
        "Sync de perfil de app y de prefs de libreta.",
        [
            req(
                "App profile meta",
                "POST",
                "/api/v1/vault/profiles/app/meta",
                description="Meta del pack de perfil de app. Sin body.",
            ),
            req(
                "App profile restore wrap",
                "POST",
                "/api/v1/vault/profiles/app/restore-wrap",
                description="Envoltorio de restauración del perfil de app. Sin body.",
            ),
            req(
                "App profile finalize",
                "POST",
                "/api/v1/vault/profiles/app/finalize",
                body={
                    "packStoragePath": "users/me/app-profile/pack.bin",
                    "packSizeBytes": 512,
                    "contentFingerprint": "fp-app",
                    "restoreWrapB64": "d3JhcA==",
                    "iconIds": ["icon-a"],
                },
                description="Finaliza pack de perfil de app.",
            ),
            req(
                "Vault profile meta",
                "POST",
                "/api/v1/vault/profiles/vault/meta",
                body=vault_id,
                description="Meta del perfil de libreta.",
            ),
            req(
                "Vault profile finalize",
                "POST",
                "/api/v1/vault/profiles/vault/finalize",
                body={
                    "vaultId": "{{vaultId}}",
                    "packStoragePath": "vaults/{{vaultId}}/profile/pack.bin",
                    "packSizeBytes": 256,
                    "contentFingerprint": "fp-vault-profile",
                    "restoreWrapB64": "d3JhcA==",
                },
                description="Finaliza pack de perfil de libreta.",
            ),
        ],
    )

    ai = folder(
        "AI",
        "Pricing de tinta, completion y transcripción (OpenAI vía backend).",
        [
            req(
                "Pricing",
                "GET",
                "/api/v1/ai/pricing",
                description="Tabla de precios/costes de operaciones IA en tinta.",
            ),
            req(
                "Complete",
                "POST",
                "/api/v1/ai/complete",
                body={
                    "prompt": "Resume esta nota en una frase.",
                    "systemPrompt": "Eres Quill, asistente de Folio.",
                    "messages": [
                        {"role": "user", "content": "Hola, ¿qué puedes hacer?"}
                    ],
                    "responseSchema": None,
                    "maxTokens": 256,
                    "temperature": 0.4,
                    "tools": None,
                    "toolChoice": None,
                    "operationKind": "quill_chat",
                },
                description="Completion de chat/IA. Cobra tinta según operación.",
            ),
            req(
                "Transcribe",
                "POST",
                "/api/v1/ai/transcribe",
                body={
                    "audioBase64": "{{audioBase64}}",
                    "language": "es",
                    "chargeInk": True,
                    "inkAmount": 1.0,
                },
                description="Transcripción de audio (base64). Puede cobrar tinta.",
            ),
        ],
    )

    integrations = folder(
        "Integrations",
        "Slack, Teams, Jira, Spotify y webhooks de captura de tareas.\n\n"
        "Comandos Slack/Teams son **públicos** con verificación de firma de plataforma.",
        [
            folder(
                "Slack & Teams",
                "Conexiones webhook, link codes, pending commands y slash/Adaptive Card commands.",
                [
                    req(
                        "Upsert webhook connection",
                        "POST",
                        "/api/v1/integrations/webhook-connection",
                        body={
                            "connectionId": "{{connectionId}}",
                            "provider": "slack",
                            "webhookUrl": "https://hooks.slack.com/services/T00/B00/XXX",
                        },
                        description="Guarda conexión webhook (slack|teams).",
                    ),
                    req(
                        "Webhook proxy",
                        "POST",
                        "/api/v1/integrations/webhook-proxy",
                        body={
                            "provider": "slack",
                            "connectionId": "{{connectionId}}",
                            "payload": {"text": "Hola desde Folio"},
                        },
                        description="Proxy autenticado hacia el webhook externo.",
                    ),
                    req(
                        "Create link code",
                        "POST",
                        "/api/v1/integrations/link-code",
                        body={
                            "code": "ABCD1234",
                            "vaultId": "{{vaultId}}",
                            "connectionId": "{{connectionId}}",
                            "provider": "slack",
                            "webhookUrl": "https://hooks.slack.com/services/T00/B00/XXX",
                            "teamsSecurityToken": None,
                        },
                        description="Código de enlace de 8 chars A-Z0-9.",
                    ),
                    req(
                        "Pending commands",
                        "POST",
                        "/api/v1/integrations/pending-commands",
                        body={"vaultId": "{{vaultId}}", "limit": 20},
                        description="Cola de comandos pendientes para el cliente.",
                    ),
                    req(
                        "Ack command",
                        "POST",
                        "/api/v1/integrations/ack-command",
                        body={
                            "commandId": "{{commandId}}",
                            "success": True,
                            "taskTitle": "Tarea creada",
                            "errorMessage": None,
                            "responseMessage": "OK",
                        },
                        description="ACK de un comando pendiente.",
                    ),
                    req(
                        "Slack command (form)",
                        "POST",
                        "/api/v1/integrations/slack/command",
                        auth=False,
                        urlencoded=[
                            {"key": "user_id", "value": "U01234567", "type": "text"},
                            {
                                "key": "text",
                                "value": "link ABCD1234",
                                "type": "text",
                            },
                        ],
                        headers=[
                            {
                                "key": "x-slack-request-timestamp",
                                "value": "{{slackTimestamp}}",
                                "type": "text",
                            },
                            {
                                "key": "x-slack-signature",
                                "value": "v0={{slackSignaturePlaceholder}}",
                                "type": "text",
                            },
                        ],
                        description=(
                            "**Público.** `application/x-www-form-urlencoded`. "
                            "Headers `x-slack-request-timestamp` + `x-slack-signature` (HMAC). "
                            "Placeholders no pasarán verificación real."
                        ),
                    ),
                    req(
                        "Slack command (JSON)",
                        "POST",
                        "/api/v1/integrations/slack/command",
                        auth=False,
                        body={"user_id": "U01234567", "text": "add Comprar leche"},
                        headers=[
                            json_header(),
                            {
                                "key": "x-slack-request-timestamp",
                                "value": "{{slackTimestamp}}",
                                "type": "text",
                            },
                            {
                                "key": "x-slack-signature",
                                "value": "v0={{slackSignaturePlaceholder}}",
                                "type": "text",
                            },
                        ],
                        description="Misma ruta Slack con `application/json` + firmas placeholder.",
                    ),
                    req(
                        "Teams command",
                        "POST",
                        "/api/v1/integrations/teams/command",
                        auth=False,
                        body={
                            "from": {"id": "29:teams-user-id"},
                            "text": "link ABCD1234",
                        },
                        query=[
                            {
                                "key": "connectionId",
                                "value": "{{connectionId}}",
                                "description": "ID de conexión Teams",
                            }
                        ],
                        headers=[
                            json_header(),
                            {
                                "key": "Authorization",
                                "value": "HMAC {{teamsHmacPlaceholder}}",
                                "type": "text",
                            },
                        ],
                        description=(
                            "**Público.** Query `connectionId`. Header `Authorization: HMAC ...` "
                            "(firma plataforma). Placeholder no verifica en local."
                        ),
                    ),
                    req(
                        "Slack OAuth exchange",
                        "POST",
                        "/api/v1/integrations/slack/oauth-exchange",
                        body={
                            "grantType": "authorization_code",
                            "code": "{{oauthCode}}",
                            "redirectUri": "http://localhost/oauth/slack",
                            "codeVerifier": "{{codeVerifier}}",
                            "clientId": "{{slackClientId}}",
                        },
                        description="Intercambia code/refresh por tokens Slack.",
                    ),
                    req(
                        "Teams OAuth exchange",
                        "POST",
                        "/api/v1/integrations/teams/oauth-exchange",
                        body={
                            "grantType": "authorization_code",
                            "code": "{{oauthCode}}",
                            "redirectUri": "http://localhost/oauth/teams",
                            "codeVerifier": "{{codeVerifier}}",
                            "clientId": "{{teamsClientId}}",
                            "scope": "openid offline_access ChannelMessage.Send",
                        },
                        description="Intercambia code/refresh por tokens Microsoft Teams.",
                    ),
                ],
            ),
            folder(
                "Jira",
                "OAuth exchange público (client secret en servidor).",
                [
                    req(
                        "Jira OAuth exchange",
                        "POST",
                        "/api/v1/integrations/jira/oauth-exchange",
                        auth=False,
                        body={
                            "code": "{{oauthCode}}",
                            "redirectUri": "http://localhost/oauth/jira",
                            "clientId": "{{jiraClientId}}",
                            "codeVerifier": "{{codeVerifier}}",
                        },
                        description="**Público** (SecurityConfig). Intercambio OAuth Atlassian.",
                    )
                ],
            ),
            folder(
                "Spotify",
                "OAuth PKCE + proxy a Web API de Spotify.",
                [
                    req(
                        "Spotify OAuth exchange",
                        "POST",
                        "/api/v1/integrations/spotify/oauth-exchange",
                        body={
                            "grantType": "authorization_code",
                            "code": "{{oauthCode}}",
                            "redirectUri": "http://localhost/oauth/spotify",
                            "codeVerifier": "{{codeVerifier}}",
                            "clientId": "{{spotifyClientId}}",
                        },
                        description="Intercambia code/refresh por tokens Spotify.",
                    ),
                    req(
                        "Spotify OAuth callback",
                        "GET",
                        "/api/v1/integrations/spotify/oauth-callback",
                        auth=False,
                        query=[
                            {"key": "code", "value": "{{oauthCode}}"},
                            {"key": "state", "value": "folio"},
                            {"key": "origin", "value": "http://localhost"},
                            {"key": "error", "value": "", "disabled": True},
                        ],
                        description="**Público.** Callback HTML del flujo OAuth (navegador).",
                    ),
                    req(
                        "Spotify API proxy",
                        "POST",
                        "/api/v1/integrations/spotify/api-proxy",
                        body={
                            "method": "GET",
                            "path": "/v1/me",
                            "accessToken": "{{spotifyAccessToken}}",
                            "headers": {},
                            "body": None,
                        },
                        description="Proxy autenticado a Spotify Web API (`path` debe empezar por `/v1/`).",
                    ),
                ],
            ),
        ],
    )

    diagnostics = folder(
        "Diagnostics",
        "Reportes de diagnóstico / bugs (público).",
        [
            req(
                "Report diagnostic",
                "POST",
                "/api/v1/diagnostics/report",
                auth=False,
                body={
                    "installId": "{{installId}}",
                    "kind": "manual",
                    "appVersion": "1.0.0+postman",
                    "platform": "windows",
                    "channel": "dev",
                    "userNote": "Prueba desde Postman",
                    "logExcerpt": "ERROR example stack…",
                    "signature": "{{diagnosticSignature}}",
                    "telemetryEnabled": False,
                },
                description=(
                    "**Público.** Requiere `installId`. Opcionales: kind, appVersion, platform, "
                    "channel, userNote, logExcerpt, signature, telemetryEnabled."
                ),
            )
        ],
    )

    collab = folder(
        "Collab",
        "Salas de colaboración (control-plane REST). Sync en vivo vía STOMP en carpeta WebSocket.",
        [
            req(
                "Create room",
                "POST",
                "/api/v1/collab/rooms",
                body={"vaultPageId": "{{vaultPageId}}"},
                description="Crea sala de collab para una página.",
            ),
            req(
                "Join room",
                "POST",
                "/api/v1/collab/rooms/join",
                body={"joinCode": "{{joinCode}}"},
                description="Une al usuario con código de invitación.",
            ),
            req(
                "Get room",
                "GET",
                "/api/v1/collab/rooms/{{roomId}}",
                description="Detalle de sala (miembros, contenido, versión).",
            ),
            req(
                "Update room",
                "PUT",
                "/api/v1/collab/rooms/{{roomId}}",
                body={
                    "title": "Página colaborativa",
                    "blocksJson": "[]",
                    "contentVersion": 1,
                    "wrappedRoomKey": None,
                    "contentCipher": None,
                    "updatedBy": "{{uid}}",
                    "changedKeys": ["title", "blocks"],
                },
                description="Actualiza contenido (last-write-wins por contentVersion).",
            ),
            req(
                "Media prepare",
                "POST",
                "/api/v1/collab/rooms/{{roomId}}/media/prepare",
                body={
                    "blockId": "block-1",
                    "mediaKind": "image",
                    "sizeBytes": 102400,
                },
                description="Prepara upload de media (presign / path).",
            ),
            req(
                "Media commit",
                "POST",
                "/api/v1/collab/rooms/{{roomId}}/media/commit",
                body={
                    "mediaId": "{{mediaId}}",
                    "blockId": "block-1",
                    "storagePath": "collab/{{roomId}}/media/block-1.bin",
                    "mediaKind": "image",
                    "sizeBytes": 102400,
                },
                description="Confirma media subida.",
            ),
            req(
                "Invite member",
                "POST",
                "/api/v1/collab/rooms/{{roomId}}/invite",
                body={"memberUid": "{{memberUid}}"},
                description="Invita miembro por UID.",
            ),
            req(
                "Remove member",
                "POST",
                "/api/v1/collab/rooms/{{roomId}}/remove-member",
                body={"memberUid": "{{memberUid}}"},
                description="Quita miembro de la sala.",
            ),
            req(
                "Close room",
                "POST",
                "/api/v1/collab/rooms/{{roomId}}/close",
                description="Cierra la sala. Sin body.",
            ),
        ],
    )

    published = folder(
        "Published Pages",
        "Páginas publicadas. GET por id es público; /mine y mutaciones requieren auth.",
        [
            req(
                "Create",
                "POST",
                "/api/v1/published-pages",
                body={"storagePath": "published/example/page.json"},
                description="Publica una página (referencia a storage).",
            ),
            req(
                "Update",
                "PUT",
                "/api/v1/published-pages/{{publishedPageId}}",
                body={"storagePath": "published/example/page-v2.json"},
                description="Actualiza storagePath de una página publicada.",
            ),
            req(
                "Delete",
                "DELETE",
                "/api/v1/published-pages/{{publishedPageId}}",
                description="Elimina página publicada.",
            ),
            req(
                "Get by id (public)",
                "GET",
                "/api/v1/published-pages/{{publishedPageId}}",
                auth=False,
                description="**Público.** Lectura de página publicada.",
            ),
            req(
                "Mine",
                "GET",
                "/api/v1/published-pages/mine",
                description="Lista páginas publicadas del usuario autenticado.",
            ),
        ],
    )

    community = folder(
        "Community Templates",
        "Plantillas comunitarias. GET list/id públicos; mutaciones con auth.",
        [
            req(
                "Create",
                "POST",
                "/api/v1/community-templates",
                body={
                    "id": "{{templateId}}",
                    "name": "Plantilla ejemplo",
                    "description": "Descripción breve",
                    "category": "productivity",
                    "emoji": "📝",
                    "blockCount": 5,
                    "storagePath": "community/{{templateId}}/template.json",
                    "storageDownloadUrl": "https://example.com/template.json",
                    "sizeBytes": 2048,
                },
                description="Crea/publica plantilla comunitaria.",
            ),
            req(
                "Update",
                "PUT",
                "/api/v1/community-templates/{{templateId}}",
                body={
                    "id": "{{templateId}}",
                    "name": "Plantilla actualizada",
                    "description": "Nueva descripción",
                    "category": "productivity",
                    "emoji": "✨",
                    "blockCount": 6,
                    "storagePath": "community/{{templateId}}/template.json",
                    "storageDownloadUrl": "https://example.com/template.json",
                    "sizeBytes": 3072,
                },
                description="Actualiza plantilla.",
            ),
            req(
                "Delete",
                "DELETE",
                "/api/v1/community-templates/{{templateId}}",
                description="Borra plantilla.",
            ),
            req(
                "Get by id (public)",
                "GET",
                "/api/v1/community-templates/{{templateId}}",
                auth=False,
                description="**Público.** Detalle de plantilla.",
            ),
            req(
                "List (public)",
                "GET",
                "/api/v1/community-templates",
                auth=False,
                description="**Público.** Listado de plantillas.",
            ),
        ],
    )

    websocket = folder(
        "WebSocket STOMP (Collab)",
        "Postman soporta WebSocket de forma limitada; este ítem documenta el contrato STOMP.\n\n"
        "**Endpoint:** `ws://localhost:8080/ws/collab` (handshake HTTP público; JWT en CONNECT).\n\n"
        "**Broker:** prefix app `/app`, broker `/topic` + `/queue`, user `/user`.\n\n"
        "**Frames:**\n"
        "1. CONNECT con header `Authorization: Bearer <accessToken>` (o según CollabStompAuthInterceptor).\n"
        "2. SUBSCRIBE destino `/topic/collab/{roomId}`.\n"
        "3. SEND destino `/app/collab/{roomId}/update` con body CollabRoomUpdateRequest "
        "(title, blocksJson, contentVersion, wrappedRoomKey, contentCipher, updatedBy, changedKeys).\n"
        "4. Errores de API → `/user/queue/collab-errors` `{error, message}`.\n"
        "5. Retransmisión de snapshot → `/topic/collab/{roomId}`.\n\n"
        "Usa un cliente STOMP (o la consola del navegador) para probar de verdad.",
        [
            {
                "name": "Collab live update (documentación)",
                "request": {
                    "method": "GET",
                    "header": [],
                    "url": {
                        "raw": "{{baseUrl}}/ws/collab",
                        "host": ["{{baseUrl}}"],
                        "path": ["ws", "collab"],
                    },
                    "description": (
                        "No es un REST GET usable: es el endpoint de handshake WebSocket/STOMP.\n\n"
                        "SEND `/app/collab/{{roomId}}/update` body ejemplo:\n"
                        "```json\n"
                        + json.dumps(
                            {
                                "title": "Live title",
                                "blocksJson": "[]",
                                "contentVersion": 2,
                                "wrappedRoomKey": None,
                                "contentCipher": None,
                                "updatedBy": "{{uid}}",
                                "changedKeys": ["title"],
                            },
                            indent=2,
                        )
                        + "\n```\n"
                        "SUBSCRIBE `/topic/collab/{{roomId}}`."
                    ),
                },
                "response": [],
            }
        ],
    )

    collection = {
        "info": {
            "_postman_id": uid(),
            "name": "Folio Cloud API",
            "description": (
                "Colección completa de la API Spring Boot de Folio (`/api/v1/...`).\n\n"
                "## Uso rápido\n"
                "1. Importa esta colección y el environment `Folio_Cloud_Local`.\n"
                "2. Arranca el stack (`docker compose up` en `backend/`).\n"
                "3. Ejecuta **Auth → Register** (o usa email/password ya existentes).\n"
                "4. Ejecuta **Auth → Login** (guarda `accessToken` / `refreshToken`).\n"
                "5. Prueba **Account → Me**.\n\n"
                "## Auth\n"
                "La mayoría de endpoints requieren `Authorization: Bearer {{accessToken}}`.\n"
                "Rutas públicas: health, auth register/login/refresh/verify/forgot/reset, "
                "billing webhook, billing catalog-prices, admin (con X-Folio-Admin-Key), "
                "diagnostics report, Slack/Teams commands, Jira oauth-exchange, "
                "Spotify oauth-callback, GET published-pages/{id}, GET community-templates.\n\n"
                "## Variables\n"
                "Ver environment local: `baseUrl`, `accessToken`, `adminApiKey`, `email`, `password`, "
                "más IDs auxiliares (`vaultId`, `roomId`, etc.).\n\n"
                "Generada a partir de controllers + OpenAPI `/v3/api-docs`."
            ),
            "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
        },
        "variable": [
            {"key": "baseUrl", "value": "http://127.0.0.1:18080"},
            {"key": "accessToken", "value": ""},
            {"key": "refreshToken", "value": ""},
            {"key": "email", "value": "postman@example.com"},
            {"key": "password", "value": "PostmanPass123!"},
            {"key": "adminApiKey", "value": "dev-admin-change-me"},
            {"key": "vaultId", "value": "00000000-0000-0000-0000-000000000001"},
            {"key": "roomId", "value": "00000000-0000-0000-0000-000000000002"},
            {"key": "uid", "value": ""},
            {"key": "memberUid", "value": ""},
            {"key": "joinCode", "value": ""},
            {"key": "vaultPageId", "value": "page-example"},
            {"key": "publishedPageId", "value": ""},
            {"key": "templateId", "value": "tmpl-example"},
            {"key": "connectionId", "value": "conn-example"},
            {"key": "commandId", "value": ""},
            {"key": "deviceId", "value": "postman-device-1"},
            {"key": "installId", "value": "postman-install-1"},
            {"key": "mediaId", "value": ""},
            {"key": "emailVerificationToken", "value": ""},
            {"key": "passwordResetToken", "value": ""},
            {"key": "oauthCode", "value": ""},
            {"key": "codeVerifier", "value": ""},
            {"key": "audioBase64", "value": ""},
            {"key": "spotifyAccessToken", "value": ""},
            {"key": "msStoreCollectionsId", "value": ""},
            {"key": "stripeSigTimestamp", "value": "0"},
            {"key": "stripeSigPlaceholder", "value": "placeholder"},
            {"key": "slackTimestamp", "value": "0"},
            {"key": "slackSignaturePlaceholder", "value": "placeholder"},
            {"key": "teamsHmacPlaceholder", "value": "placeholder"},
            {"key": "diagnosticSignature", "value": ""},
            {"key": "slackClientId", "value": ""},
            {"key": "teamsClientId", "value": ""},
            {"key": "jiraClientId", "value": ""},
            {"key": "spotifyClientId", "value": ""},
        ],
        "item": [
            health,
            auth,
            account,
            users,
            admin,
            billing,
            family,
            vault_backups,
            device_sync,
            profiles,
            ai,
            integrations,
            diagnostics,
            collab,
            published,
            community,
            websocket,
        ],
    }
    return collection


def build_environment() -> dict:
    values = [
        ("baseUrl", "http://127.0.0.1:18080", True),
        ("accessToken", "", True),
        ("refreshToken", "", True),
        ("email", "postman@example.com", True),
        ("password", "PostmanPass123!", True),
        ("adminApiKey", "dev-admin-change-me", True),
        ("vaultId", "00000000-0000-0000-0000-000000000001", True),
        ("roomId", "00000000-0000-0000-0000-000000000002", True),
        ("uid", "", True),
        ("memberUid", "", True),
        ("joinCode", "", True),
        ("vaultPageId", "page-example", True),
        ("publishedPageId", "", True),
        ("templateId", "tmpl-example", True),
        ("connectionId", "conn-example", True),
        ("commandId", "", True),
        ("deviceId", "postman-device-1", True),
        ("installId", "postman-install-1", True),
        ("mediaId", "", True),
        ("emailVerificationToken", "", True),
        ("passwordResetToken", "", True),
        ("oauthCode", "", True),
        ("codeVerifier", "", True),
        ("audioBase64", "", True),
        ("spotifyAccessToken", "", True),
        ("msStoreCollectionsId", "", True),
    ]
    return {
        "id": uid(),
        "name": "Folio Cloud Local",
        "values": [
            {"key": k, "value": v, "type": "default", "enabled": en} for k, v, en in values
        ],
        "_postman_variable_scope": "environment",
    }


def count_requests(items: list) -> int:
    n = 0
    for it in items:
        if "item" in it:
            n += count_requests(it["item"])
        else:
            n += 1
    return n


def main() -> None:
    col = build()
    env = build_environment()
    col_path = OUT / "Folio_Cloud_API.postman_collection.json"
    env_path = OUT / "Folio_Cloud_Local.postman_environment.json"
    col_path.write_text(json.dumps(col, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    env_path.write_text(json.dumps(env, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    n = count_requests(col["item"])
    print(f"Wrote {col_path.name} ({n} requests)")
    print(f"Wrote {env_path.name}")


if __name__ == "__main__":
    main()
