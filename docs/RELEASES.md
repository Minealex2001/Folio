# Releases y actualizaciones

Este documento define la convención para publicar releases en GitHub compatibles con el actualizador integrado de Folio (Windows `.exe` y Android `.apk`).

## Convención de tags

| Tipo | Tag | Ejemplo |
|------|-----|---------|
| **Global** | `vMAJOR.MINOR.PATCH` | `v1.4.0` |
| **Solo plataforma** | `vMAJOR.MINOR.PATCH-<platform>` | `v1.4.0-android`, `v1.4.0-windows`, `v1.4.0-linux`, `v1.4.0-macos` |

- El prefijo `v` es la convención oficial; el parser también acepta tags sin `v`.
- El sufijo `-android` / `-windows` / etc. **no** forma parte del semver: el updater lo elimina antes de comparar (`v1.4.0-android` ≡ versión `1.4.0`).
- Canal **Beta** = flag GitHub `--prerelease` (aplica a tags globales y de plataforma).
- Si un tag ya existe, `builld_all.ps1` hace `gh release upload --clobber` (añadir/actualizar assets) en lugar de fallar.

## Convención de nombres de assets

| Asset | Uso |
|--------|-----|
| `Folio-Setup-MAJOR.MINOR.PATCH.exe` | Instalador Windows (Inno Setup). Necesario para auto-update en Windows. |
| `Folio-Windows-GitHub-<ver>.zip` | Build portable Windows (canal GitHub). |
| `Folio-MicrosoftStore-<ver>.msix` | Paquete para Partner Center / sideload Store. |
| `Folio-Android-PlayStore-<ver>.apk` | APK Android (updater en Android y sideload). |
| `Folio-Android-PlayStore-<ver>.aab` | App Bundle para Google Play Console. |
| `Folio-Linux-GitHub-<ver>.zip` | Bundle Linux (`bundle/`). |
| `Folio-macOS-GitHub-<ver>.zip` | App macOS (`.app` empaquetada). |

- Ejemplo instalador: `Folio-Setup-1.3.0.exe`.
- `<ver>` usa la versión de `pubspec.yaml` con `+` sustituido por `-` (p. ej. `1.3.0-12`).
- El updater en Windows prioriza `.exe` con `setup`/`installer` en el nombre; en Android prioriza `.apk`.

## Cómo elige el updater

1. Lista releases recientes de GitHub (no solo `releases/latest`).
2. Filtra: no draft; canal estable → sin `--prerelease`; beta → estable o pre.
3. Tag **global** o con sufijo de la plataforma actual (`-android` / `-windows`).
4. Debe incluir asset instalable para esa plataforma.
5. Gana la **mayor semver**; empate → preferir estable sobre pre, luego tag global sobre tag de plataforma.

Así una pre-release solo Android (`v1.4.1-android`) no tapa updates de Windows, y un `v1.4.1-android` sí compite con un global `v1.4.0`.

## Checklist de publicación

1. Incrementar `version` en `pubspec.yaml` (opción 12 del menú, o a mano).
2. Ejecutar `.\builld_all.ps1` y seguir los menús (canal → alcance → plataformas si aplica).
3. Confirmar el tag en GitHub (`vX.Y.Z` o `vX.Y.Z-<platform>`) y los assets.

> **Linux / macOS desde Windows:** Linux vía **WSL** si Flutter+GTK están en la distro; macOS requiere Mac o el job `macos` de `folio-build-all`.

## Betas (canal Beta en la app)

En Ajustes → Acerca de → canal **Beta**: el updater considera estables y pre-releases con asset para la plataforma (véase arriba).

## `FOLIO_DISTRIBUTION` (facturación Folio Cloud)

El instalador de GitHub se compila con `--dart-define=FOLIO_DISTRIBUTION=github` (definido en el workflow de release). Eso **desactiva la integración Microsoft Store** en la app (compras IAP de la Tienda y sync asociada); **Stripe en navegador sigue activo**.

| Valor | Uso típico |
|--------|------------|
| `github` | Instalador Windows desde releases (sin Microsoft Store en UI). |
| `microsoft_store` | MSIX / Partner Center; los `MS_STORE_*` deben coincidir con `functions/.env` (backend). El script `builld_all.ps1` los lee de ahí y los pasa como `--dart-define` solo en el build Windows Store (ver `lib/services/folio_cloud/folio_microsoft_store_products.dart`). |
| `play_store` | Reservado para builds Android publicados en Google Play (sin Microsoft Store). |
| *(vacío)* | Legado / desarrollo local: en Windows puede ofrecerse Tienda además de Stripe si el runtime y los defines lo permiten. |

En builds `microsoft_store` y `play_store`, la app **no** ofrece descarga/instalación de actualizaciones desde GitHub (`FolioDistribution.offersGitHubSelfUpdate`); las tiendas gestionan esas actualizaciones. Las **notas de versión** de la release en GitHub siguen pudiendo mostrarse (solo lectura). En Ajustes, **Buscar actualizaciones** abre la ficha en Microsoft Store o Google Play: en Windows Store define `FOLIO_MS_STORE_LISTING_PRODUCT_ID` (id de producto de Partner Center; `builld_all.ps1` lo lee también desde `functions/.env` si la línea está presente). En Play, por defecto se usa el `applicationId` de Android; opcional `--dart-define=FOLIO_PLAY_STORE_APP_ID=...`.

## Publicación local con `builld_all.ps1`

Todo el flujo humano es por **menús numerados** (sin flags):

```powershell
.\builld_all.ps1
```

1. Elige **RELEASE estable**, **PRE-RELEASE / Beta** o **solo notas**.
2. Elige el **alcance**: Global / Android / Windows / Linux / macOS  
   (tag `vX.Y.Z` o `vX.Y.Z-<plataforma>`).
3. Si eliges **Global**, un segundo menú te deja marcar/desmarcar plataformas (Windows, MSIX, Android, Linux, macOS).
4. Confirmas con **1) Sí / 2) No** y pegas notas Markdown (o Enter para autogenerar).

Compilar sin publicar, limpiar o cambiar versión también están en el mismo menú.

### Enlaces web (folio vs foliobeta)

| Elección en el menú | Enlaces embebidos (`FOLIO_WEB_BASE_URL`) |
|---|---|
| RELEASE estable | `https://folio.minealexgames.com` |
| PRE-RELEASE / Beta | `https://foliobeta.minealexgames.com` |

**App web (Vercel):** el host `folio` / `foliobeta` se detecta en runtime. **Backend (Railway):** `FOLIO_WEB_BASE_URL=https://folio.minealexgames.com` en prod.

Requisitos: [GitHub CLI](https://cli.github.com/) autenticado e [Inno Setup](https://jrsoftware.org/isinfo.php) cuando publiques Windows.

> **Notas Markdown:** pega el cuerpo y termina con una línea `END`; Enter vacío en la primera línea usa notas autogeneradas.

> El destino del tag se resuelve automáticamente (rama actual en `origin` o rama por defecto). Empuja tus cambios antes de publicar.

## Workflow «Folio build all» (GitHub Actions)

- Archivo: [`.github/workflows/folio-build-all.yml`](../.github/workflows/folio-build-all.yml) (manual).
- Jobs: Windows, Android, Linux, macOS → artifacts. Puedes adjuntarlos a un tag global o de plataforma con `gh release upload`.

## OAuth móvil (redirect URIs)

En Android/iOS el OAuth de integraciones usa deep link `folio://oauth/<provider>/callback` (no loopback). Registrar en cada IdP:

| Provider | Redirect URI |
|----------|----------------|
| Jira (Atlassian) | `folio://oauth/jira/callback` |
| Spotify | `folio://oauth/spotify/callback` |
| Slack | `folio://oauth/slack/callback` |
| Teams (Azure) | `folio://oauth/teams/callback` |

Desktop sigue usando `http://127.0.0.1:45747–45750/callback`. El backend acepta ambos.

## Notas operativas

- El updater se apoya en el endpoint público de releases para producción.
- Si el nombre del `.exe`/`.apk` no respeta la convención, la detección automática puede fallar.
