# Integración Slack / Teams — estado de implementación

Estado actual: **Fase 1 (notificaciones salientes vía webhook) y Fase 3 (comandos entrantes v1) implementadas** en Ajustes → Integraciones (Beta). La Fase 2 (OAuth) sigue pendiente.

## Implementado — Fase 1

- [x] Modelos de conexión (`SlackConnection`/`TeamsConnection`) basados en Incoming Webhook URL, sin OAuth.
- [x] Clientes API (`SlackApiClient`/`TeamsApiClient`) que hacen POST al webhook.
- [x] `IntegrationNotificationDispatcher` compartido: notifica cambios de estado de tarea, tareas nuevas y comentarios nuevos.
- [x] UI de Ajustes (tarjeta + diálogo Conexiones/Notificaciones/Comandos) para ambos proveedores, con insignia BETA.
- [x] Persistencia en el vault (`vault_payload.dart` esquema v12) y wiring en `VaultSession`.
- [x] Cadenas localizadas en los 6 idiomas del repo (en/es/pt/ca/eu/gl).
- [x] **Proxy CORS para build Web:** callable `folioIntegrationWebhookProxy` (auth Firebase + whitelist de hostnames).
- [x] **Logos de marca:** `appLogos/slack.png`, `appLogos/microsoftTeams.png` en `pubspec.yaml` y UI.
- [x] **Sync multi-dispositivo:** `slack`/`teams` (y `github`/`gitlab`) propagados en `vault_sync_merge.dart` y `vault_migration.dart`.

## Implementado — Fase 3 (comandos entrantes v1, sin OAuth)

- [x] Cloud Functions `folioSlackCommand` / `folioTeamsCommand` (`onRequest`, verificación de firma Slack / HMAC Teams Outgoing Webhook).
- [x] Callables `folioRegisterIntegrationLinkCode`, `folioAckIntegrationCommand`, buzón `users/{uid}/pendingIntegrationCommands`.
- [x] Índice servidor `integrationUserIndex/{provider}_{externalUserId}` (solo metadatos opacos, sin contenido del vault).
- [x] Cliente: `IntegrationCommandProcessor` procesa el buzón al tener vault desbloqueado + sesión Firebase.
- [x] Alcance v1: `/folio link CODE` y `/folio create task "<título>"`.
- [x] Ack inmediato en Slack/Teams indicando que la aplicación no es instantánea.

### Configuración manual requerida

| Proveedor | Qué configurar |
|-----------|----------------|
| **Slack** | App con slash command `/folio` → URL `folioSlackCommand`; secret `SLACK_SIGNING_SECRET` en Functions |
| **Teams** | Outgoing Webhook por canal → URL `folioTeamsCommand?connectionId=<id>`; token HMAC en la conexión Folio |

## Pendiente — Fase 2 (OAuth + identidad)

- [ ] Registrar app Slack (scopes bot) y app Azure AD (Graph).
- [ ] `SlackAuthService`/`TeamsAuthService` (OAuth 2.0 + PKCE).
- [ ] Cloud Functions `folioSlackExchangeOAuth`/`folioTeamsExchangeOAuth`.
- [ ] Bot API (`chat.postMessage`, Graph) en lugar de solo webhooks.
- [ ] Secretos `SLACK_OAUTH_*` / `TEAMS_OAUTH_*` en `folio_local_secrets.example.dart`.

## Fuera de alcance (sin cambios)

- @menciones reales en `assignee`, login vía Slack/Teams, FCM/push para latencia instantánea.

## Verificación manual pendiente

- [ ] Prueba end-to-end con webhooks y comandos reales en canales de Slack/Teams.
