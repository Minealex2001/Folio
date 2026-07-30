# Releases y actualizaciones (Windows)

Este documento define la convención para publicar releases en GitHub que sean compatibles con el actualizador integrado de Folio en Windows.

## Convención de versiones

- El tag de release debe seguir semver estable: `vMAJOR.MINOR.PATCH`.
- Ejemplos válidos: `v1.0.0`, `v1.2.3`.
- El actualizador acepta el prefijo `v` opcional al parsear (`1.2.3` también se interpreta), pero la convención oficial del repositorio es usar `v`.

## Convención de nombres de assets

| Asset | Uso |
|--------|-----|
| `Folio-Setup-MAJOR.MINOR.PATCH.exe` | Instalador Windows (Inno Setup). **Obligatorio** para el auto-updater en Windows. |
| `Folio-Windows-GitHub-<ver>.zip` | Build portable Windows (canal GitHub). |
| `Folio-MicrosoftStore-<ver>.msix` | Paquete para Partner Center / sideload Store. |
| `Folio-Android-PlayStore-<ver>.apk` | APK Android (updater en Android y sideload). |
| `Folio-Android-PlayStore-<ver>.aab` | App Bundle para Google Play Console. |
| `Folio-Linux-GitHub-<ver>.zip` | Bundle Linux (`bundle/`). |
| `Folio-macOS-GitHub-<ver>.zip` | App macOS (`.app` empaquetada). |

- Ejemplo instalador: `Folio-Setup-1.3.0.exe`.
- `<ver>` usa la versión de `pubspec.yaml` con `+` sustituido por `-` (p. ej. `1.3.0-12`).
- El updater en Windows prioriza `.exe` que contenga `setup` o `installer` en el nombre; en Android prioriza `.apk`.

## Checklist de publicación

1. Incrementar `version` en `pubspec.yaml` (o usar `-BumpVersion` en el script).
2. Ejecutar release/prerelease con `builld_all.ps1` (compila **todas** las formas posibles en el host actual).
3. Crear release en GitHub con tag `vMAJOR.MINOR.PATCH` y adjuntar los assets generados.
4. Publicar la release (o marcar pre-release para el canal Beta).

> **Linux / macOS desde Windows:** Linux se intenta vía **WSL** si Flutter+deps GTK están en la distro; macOS **no** se puede cross-compilar (hace falta un Mac o el job `macos` del workflow `folio-build-all`). Para una release completa multiplataforma, compila con Actions y adjunta los artefactos, o publica desde el script en cada host.

## Betas (canal Beta en la app)

En Ajustes → Acerca de puedes elegir el canal **Beta**. Ese modo usa la **última release de GitHub marcada como pre-release** (no borrador), no el endpoint `releases/latest`.

- Al crear la release en GitHub, marca **“Set as a pre-release”** / **“This is a pre-release”**.
- Misma convención de tag semver y mismo nombre de asset `.exe` que en releases estables.
- Si no hay ninguna pre-release publicada, la app indicará que no hay betas disponibles.

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

Además del CI, puedes compilar y publicar desde tu máquina con el menú interactivo del script:

```powershell
.\builld_all.ps1
```

- **Opción 1 (RELEASE estable):** compila **todas** las formas de distribución posibles en el host (instalador `.exe`, ZIP Windows, MSIX, APK/AAB, Linux vía WSL si aplica, macOS solo en Mac) y ejecuta `gh release create v<semver> ...` adjuntando todos los assets. Antes de publicar pide pegar **notas Markdown** (o Enter para `--generate-notes`).
- **Opción 2 (PRE-RELEASE / Beta):** igual pero con `--prerelease` (marca la release como pre-release para el canal Beta); mismas opciones de notas Markdown.
- **Opción 3 (solo notas):** crea la release/changelog sin adjuntar artefactos (también admite Markdown pegado o archivo).

Modo directo (sin menú), útil para automatizar:

```powershell
# Release estable de la versión actual de pubspec.yaml
.\builld_all.ps1 -Action release -Yes

# Pre-release subiendo antes la versión
.\builld_all.ps1 -Action prerelease -BumpVersion 1.4.0 -Yes

# Notas Markdown desde archivo (release o prerelease)
.\builld_all.ps1 -Action release -Yes -ReleaseNotesFile .\CHANGELOG-release.md
.\builld_all.ps1 -Action prerelease -Yes -ReleaseNotes "## Beta`n`n- Fix X"

# Solo plataformas Windows (omitir Android/Linux/macOS)
.\builld_all.ps1 -Action release -Yes -SkipAndroid -SkipLinux -SkipMacOS
```

### Enlaces web (folio vs foliobeta)

| Canal del script | Enlaces embebidos en el binario (`FOLIO_WEB_BASE_URL`) |
|---|---|
| `-Action release` (menú 1) | `https://folio.minealexgames.com` |
| `-Action prerelease` (menú 2) | `https://foliobeta.minealexgames.com` |

Override manual: `-FolioWebBaseUrl https://foliobeta.minealexgames.com`.

**App web (Vercel):** el proyecto `folio` despliega con `vercel-build.sh`. Si el usuario abre `foliobeta…` o `folio…`, la web detecta el host solo (no hace falta dart-define en ese build). Añade el dominio `foliobeta.minealexgames.com` al mismo proyecto Vercel (o a un alias de Production/Preview) apuntando al deploy que quieras como beta.

**Backend (correos / `publicUrl`):** en Railway, `FOLIO_WEB_BASE_URL=https://folio.minealexgames.com` (prod). Solo cambia a foliobeta si tienes un API de staging/beta.

Requisitos: [GitHub CLI](https://cli.github.com/) (`gh`) autenticado (`gh auth login`) e [Inno Setup](https://jrsoftware.org/isinfo.php) (`ISCC.exe`) para el instalador. Opcional: WSL con Flutter para Linux; host macOS para el `.app`. Parámetros útiles: `-ReleaseTag`, `-ReleaseTarget`, `-ReleaseNotes`, `-ReleaseNotesFile`, `-DraftRelease`, `-Clean`, `-SkipMicrosoftStore`, `-SkipAndroid`, `-SkipLinux`, `-SkipMacOS`, `-FolioWebBaseUrl`.

> **Notas Markdown:** en modo interactivo (menú 1/2/3), pega el cuerpo y termina con una línea `END`; Enter vacío en la primera línea usa `--generate-notes`. Con `-Yes` / `-NonInteractive` sin `-ReleaseNotes`/`-ReleaseNotesFile` también se autogeneran. El script pasa el Markdown a `gh` vía `--notes-file` (archivo temporal UTF-8).

> El `target_commitish` se resuelve automáticamente: si omites `-ReleaseTarget`, el script usa la rama actual (si existe en `origin`) o la rama por defecto del remoto (`main`). GitHub crea el tag apuntando al **último commit de esa rama en el remoto**, así que empuja tus cambios antes de publicar.

## Workflow «Folio build all» (GitHub Actions)

- Archivo: [`.github/workflows/folio-build-all.yml`](../.github/workflows/folio-build-all.yml) (manual: **Actions → Folio build all → Run workflow**).
- Jobs en paralelo: **Windows** (`builld_all.ps1 -SkipAndroid -SkipLinux -SkipMacOS`), **Android** (APK + AAB), **Linux** (ZIP del bundle) y **macOS** (ZIP del `.app`). Artefactos: `folio-output-windows`, `folio-output-android`, `folio-output-linux`, `folio-output-macos`.
- Opcional: secret **`FOLIO_MS_STORE_ENV`** (texto multilínea con líneas `MS_STORE_*=…`) para inyectar ids de producto en el build Store del job Windows; sin él, el paso MSIX puede fallar si faltan defines (marca **Omitir MSIX** en el workflow si solo quieres el ZIP GitHub).

## Notas operativas

- El repositorio puede ser privado durante desarrollo, pero el updater se apoya en el endpoint público de releases para producción.
- Si el nombre del `.exe` no respeta esta convención, la detección automática puede fallar.
