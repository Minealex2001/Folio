# Integración Slack / Teams — estado de implementación

Estado actual: **Fase 1 (webhooks)**, **Fase 2 (OAuth PKCE + Bot/Graph)** y **Fase 3 (comandos entrantes)** implementadas en Ajustes → Integraciones (Beta).

## Implementado — Fase 1

- [x] Modelos de conexión (`SlackConnection`/`TeamsConnection`) basados en Incoming Webhook URL, sin OAuth.
- [x] Clientes API (`SlackApiClient`/`TeamsApiClient`) que hacen POST al webhook.
- [x] `IntegrationNotificationDispatcher` compartido: notifica cambios de estado de tarea, tareas nuevas y comentarios nuevos.
- [x] Cola de reintentos con backoff (máx. 3 intentos) en el dispatcher.
- [x] UI de Ajustes (tarjeta + diálogo Conexiones/Notificaciones/Comandos) para ambos proveedores, con insignia BETA.
- [x] Persistencia en el vault y wiring en `VaultSession`.
- [x] Cadenas localizadas en los 6 idiomas del repo (en/es/pt/ca/eu/gl).
- [x] **Proxy CORS para build Web:** callable `folioIntegrationWebhookProxy`.
- [x] **Export** `folioUpsertIntegrationWebhookConnection` en `functions/src/index.ts`.

## Implementado — Fase 2 (OAuth)

- [x] `SlackAuthService` / `TeamsAuthService` (OAuth 2.0 + PKCE, loopback `45749` / `45750`).
- [x] Cloud Functions `folioSlackExchangeOAuth` / `folioTeamsExchangeOAuth` (Bearer Firebase).
- [x] Campos OAuth en conexiones (`accessToken`, `refreshToken`, `channelId`/`teamId`, …).
- [x] `chat.postMessage` / Graph channel message cuando hay token + ids; fallback a webhook.
- [x] Botón «Conectar con OAuth» en Ajustes Slack (requiere `SLACK_OAUTH_CLIENT_ID` y sesión Folio Cloud).
- [ ] Registrar apps oficiales Slack / Azure AD en producción y rellenar secretos.

## Implementado — Fase 3 (comandos entrantes)

- [x] Cloud Functions `folioSlackCommand` / `folioTeamsCommand`.
- [x] Comandos: `link`, `create task`, `list tasks`, `complete task` / `done`.
- [x] Polling en **Windows** vía callable `folioListPendingIntegrationCommands` (Admin SDK; el list REST devolvía 403).
- [x] Ack con `responseMessage` personalizado.

## Fuera de alcance (sin cambios)

- @menciones reales en `assignee`, login vía Slack/Teams, FCM/push para latencia instantánea.

## Verificación manual pendiente

- [ ] Prueba end-to-end con webhooks, OAuth y comandos reales en canales de Slack/Teams.
