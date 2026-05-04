# Releases y actualizaciones (Windows)

Este documento define la convención para publicar releases en GitHub que sean compatibles con el actualizador integrado de Folio en Windows.

## Convención de versiones

- El tag de release debe seguir semver estable: `vMAJOR.MINOR.PATCH`.
- Ejemplos válidos: `v1.0.0`, `v1.2.3`.
- El actualizador acepta el prefijo `v` opcional al parsear (`1.2.3` también se interpreta), pero la convención oficial del repositorio es usar `v`.

## Convención de nombres de assets

- Asset principal de Windows: `Folio-Setup-MAJOR.MINOR.PATCH.exe`.
- Ejemplo: `Folio-Setup-1.3.0.exe`.
- El updater prioriza `.exe` que contenga `setup` o `installer` en el nombre.

## Checklist de publicación

1. Incrementar `version` en `pubspec.yaml`.
2. Generar el instalador de Windows para la versión.
3. Crear release en GitHub con tag `vMAJOR.MINOR.PATCH`.
4. Adjuntar el asset `.exe` siguiendo el patrón definido.
5. Publicar la release.

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

## Workflow «Folio build all» (GitHub Actions)

- Archivo: [`.github/workflows/folio-build-all.yml`](../.github/workflows/folio-build-all.yml) (manual: **Actions → Folio build all → Run workflow**).
- Tres jobs en paralelo: **Windows** (ejecuta `builld_all.ps1 -SkipAndroid -SkipLinux`), **Android APK** y **Linux** (ZIP del bundle). Artefactos: `folio-output-windows`, `folio-output-android`, `folio-output-linux`.
- Opcional: secret **`FOLIO_MS_STORE_ENV`** (texto multilínea con líneas `MS_STORE_*=…`) para inyectar ids de producto en el build Store del job Windows; sin él, el paso MSIX puede fallar si faltan defines (marca **Omitir MSIX** en el workflow si solo quieres el ZIP GitHub).

## Notas operativas

- El repositorio puede ser privado durante desarrollo, pero el updater se apoya en el endpoint público de releases para producción.
- Si el nombre del `.exe` no respeta esta convención, la detección automática puede fallar.
