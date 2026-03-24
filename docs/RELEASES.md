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

## Notas operativas

- El repositorio puede ser privado durante desarrollo, pero el updater se apoya en el endpoint público de releases para producción.
- Si el nombre del `.exe` no respeta esta convención, la detección automática puede fallar.
