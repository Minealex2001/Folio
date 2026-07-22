---
name: Ajustes Música e Integraciones
overview: Reorganizar solo la UI de Ajustes — subsección «Música» dentro de Integraciones (con Spotify), y mover la sección Integraciones encima de Acerca de en el rail. Sin YT Music ni cambios de vault/backend.
todos:
  - id: nav-order
    content: "Reordenar rail de Ajustes: Integraciones encima de Acerca de"
    status: completed
  - id: music-subsection
    content: Subsección Música dentro de Integraciones con Spotify (sacar de nativas)
    status: completed
  - id: l10n-docs
    content: Claves l10n settingsIntegrationsMusicTitle + actualizar FEATURES.md
    status: completed
isProject: false
---

# Ajustes: apartado Música + orden del rail

## Alcance (reducido)

- **No** se implementa YT Music ni exclusividad de proveedores.
- **No** hay cambios de vault, Cloud Functions, reproducción ni editor.
- Solo reorganización de UI en Ajustes.

## 1. Rail de navegación: Integraciones encima de Acerca de

Hoy en [`lib/features/settings/settings_page.dart`](lib/features/settings/settings_page.dart) (~L712–746) el orden es:

```
… → Sync → Acerca de → Integraciones
```

Cambiar a:

```
… → Sync → Integraciones → Acerca de
```

También actualizar el orden del enum [`_SettingsSectionId`](lib/features/settings/settings_page_folio_cloud.dart) (poner `integrations` antes de `about`) para mantener consistencia con switches/`values`.

## 2. Subsección «Música» dentro de Integraciones

Seguir **dentro** de la pestaña Integraciones (no crear sección nueva del rail).

Estructura objetivo:

```
Integraciones nativas
  Jira, YouTrack, Trello, GitHub, GitLab, Slack, Teams

Música                          ← nuevo subtítulo (l10n)
  SpotifyIntegrationCard

Conexiones activas
  …
```

En [`settings_page.dart`](lib/features/settings/settings_page.dart) (~L5208–5211):
- Quitar `SpotifyIntegrationCard` de la lista bajo «Integraciones nativas».
- Tras Teams, añadir subtítulo `settingsIntegrationsMusicTitle` (mismo estilo tipográfico que `settingsIntegrationsNativeTitle`) + `SpotifyIntegrationCard`.

## 3. Localización y docs

- Añadir `settingsIntegrationsMusicTitle` en los 6 `.arb` (`en`/`es`/`ca`/`pt`/`eu`/`gl`): «Music» / «Música» / etc.
- Regenerar l10n.
- Actualizar [`FEATURES.md`](FEATURES.md) §29c: ruta UI → **Ajustes → Integraciones → Música → Spotify**.

## Archivos a tocar

- [`lib/features/settings/settings_page.dart`](lib/features/settings/settings_page.dart) — orden del rail + subsección Música
- [`lib/features/settings/settings_page_folio_cloud.dart`](lib/features/settings/settings_page_folio_cloud.dart) — orden enum `_SettingsSectionId`
- `lib/l10n/app_{en,es,ca,pt,eu,gl}.arb` — clave del subtítulo
- [`FEATURES.md`](FEATURES.md) — documentación mínima
