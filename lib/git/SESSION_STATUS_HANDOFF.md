# Estado real del rediseño de sync/backup (v0→v1) — traspaso

Este documento es un traspaso honesto para quien continúe este trabajo (humano
o IA). No es una nota de "todo listo" — varias de esas notas anteriores en
este mismo directorio (`README.md`, `BETA_IMPLEMENTATION_CHECKLIST.md`, etc.)
afirmaban cosas que luego resultaron no ser ciertas ("34/34 tests" probando
lógica simulada, no el código real integrado). Este documento intenta no
repetir ese error: dice qué está verificado, qué no, y qué sigue roto.

## Qué se está construyendo

Sustituir el formato de libreta monolítico (`vault.bin` = un JSON/blob
cifrado con todo dentro) por un árbol de archivos (`<vault>/repo/`, un
archivo por página/bloque), más un sistema de versionado local basado en
snapshots (`<vault>/versions/`), manteniendo el transporte de sync existente
(P2P LAN + Firebase Cloud). Ver el plan original completo en
`lib/git/VAULT_GIT_FORMAT.md` y `lib/git/README.md` para el diseño; este
documento es solo el estado real de la implementación.

- **v0** = formato viejo: `vault.bin` monolítico, revisiones por página en
  memoria (`_pageRevisions`).
- **v1** = formato nuevo: árbol en `<vault>/repo/{tree.json, pages/<id[0:2]>/<id>/{meta.json,blocks.jsonl,comments.jsonl}, vault/...}`,
  snapshots comprimidos en `<vault>/versions/<id>.{json,zip}`.
- Migración v0→v1 es **obligatoria** y automática: ocurre en el primer
  `bootstrap()`/desbloqueo de cualquier libreta v0, cifrada o no.

## Archivos clave

### Núcleo del formato (de sesiones anteriores, ya committeados)
- `lib/git/vault_payload_converters.dart` — `VaultPayloadToTree.decompose()` /
  `TreeToVaultPayload.compose()`. **Bug conocido sin arreglar**:
  `_parseProperties()` (línea ~472) es un stub que siempre devuelve `[]` —
  **las `properties` de página (campos tipo base de datos) se pierden en
  cada round-trip por el árbol**. No se ha tocado en esta sesión porque no
  se detectó hasta ahora; hay que arreglarlo antes de confiar en v1 con
  libretas que usen properties.
- `lib/git/vault_snapshot.dart` — modelo `VaultSnapshot`/`FileManifestEntry`
  (`path`, `sha256`, `sizeBytes` por archivo).
- `lib/git/vault_snapshot_manager.dart` — creación/listado/borrado de
  snapshots. **Esta sesión**: `_computeSha256()` y
  `_compressAndStoreTreeSnapshot()` eran placeholders reales (hash falso,
  ZIP no-op) — se arreglaron para usar SHA-256 real
  (`package:cryptography`) y ZIP real (reutilizando `P2PSyncPackager`).
  `restoreSnapshot()` también era un placeholder (`return false` siempre) —
  ahora restaura de verdad. Se añadió `extractFilesFromSnapshot()` para leer
  archivos concretos de un snapshot sin descomprimir el árbol entero (ver
  sección de historial de versiones más abajo).
- `lib/git/vault_migration_tool.dart` — `migrateVault()`, marker
  `vault.format` (0/1), `readTreeFormatVersion()`.
- `lib/git/vault_format_handler.dart` — **esta sesión**: se eliminaron los
  métodos que nunca se usaban (`captureRevisionIfChanged`, `persistPayload`,
  `getVersions`, `restoreVersion`, `autoMigrateIfNeeded`) porque
  `vault_session.dart` reimplementó la misma lógica inline sin llamarlos —
  quedaban dos implementaciones paralelas sin sincronizar. Solo quedan
  `detectFormat()`, `loadPayload()`, `formatStats()`.
- `lib/data/vault_local_storage.dart` — **esta sesión**: `loadFromTree()`
  comprobaba `treeDir.existsSync()` para decidir si había árbol v1, pero
  `VaultPaths.vaultTreeDirectory()` crea ese directorio como efecto
  secundario si no existe — la comprobación nunca podía dar `false`. Se
  cambió a comprobar `tree.json` específicamente. Esto era la causa más
  probable de que una libreta con árbol v1 incompleto se cargara como
  libreta vacía en vez de caer al respaldo v0.

### Sesión (`vault_session.dart`) — cambios grandes esta sesión
- `bootstrap()`: migración obligatoria ahora se aplica también a libretas
  **cifradas** (antes solo aplicaba a libretas en claro). `_ensureV1AndLoad()`
  es el método compartido que migra si hace falta y carga el payload; lo
  usan `bootstrap()`, `unlockWithPassword()` (ambas ramas), 
  `unlockWithDeviceAuth()`, `unlockWithPasskey()`.
- `_ensureFormatHandlerReady()`: inicialización perezosa e idempotente de
  `_formatHandler`/`_deviceId`/`_vaultFormatVersion` — antes varios flujos
  de creación de libreta (`completeOnboarding`, onboarding desde backup)
  podían disparar `LateInitializationError` porque asumían que `bootstrap()`
  ya había corrido.
- `completeOnboarding()`: las libretas nuevas ahora nacen directamente en
  v1 (antes se quedaban en v0 hasta el próximo `bootstrap()`).
- Catch más amplio en `bootstrap()`: antes solo capturaba
  `VaultCorruptionException`; un `StateError` sin capturar dejaba la sesión
  atascada en `VaultFlowState.initializing` (pantalla de carga infinita)
  sin mensaje de error. Ahora cualquier excepción cae a
  `VaultFlowState.recovery`.
- `vaultBinEquivalentBytes()`: bytes equivalentes a `vault.bin` calculados
  desde el payload en memoria (cifrados si aplica), sin tocar disco.
  Necesario porque **todo el pipeline de backups en la nube leía
  `vault.bin` directamente del disco**, y `persistNow()` en v1 dejó de
  escribir ese archivo — sin este cambio, las copias en la nube de
  cualquier libreta migrada habrían quedado congeladas para siempre (o
  habrían fallado si se borraba `vault.bin`). Ver más abajo.
- `versionsForPage(pageId)` / `restoreVersion(versionId)` / `deleteVersion()`:
  ver sección "Historial de versiones" — es la parte que **el usuario
  reporta que sigue sin funcionar bien** al final de esta sesión, sin
  confirmar todavía si es un bug real o un build no actualizado.

### Pipeline de backups en la nube — reescrito esta sesión
Se encontró que **5 funciones** leían `vault.bin` directamente del disco en
vez de usar el estado en memoria, lo cual se rompía en cuanto una libreta
migraba a v1 (el archivo deja de actualizarse) o se borraba (el usuario
pidió explícitamente poder borrar `vault.bin` tras migrar):

- `lib/data/vault_backup.dart`: `computeVaultCloudBackupFingerprint()`,
  `computeVaultCloudPackContentFingerprint()`, `exportVaultZip()`,
  `exportVaultTarGz()` — las 4 ahora reciben `vaultBinBytes`/`Uint8List` en
  vez de leer el archivo.
- `lib/services/vault_pack/vault_pack_builder.dart`:
  `buildVaultPackSnapshot()` — igual.
- Llamadores actualizados: `folio_cloud_pack_sync.dart`,
  `vault_pack_sync.dart`, `folio_cloud_backup.dart`,
  `backup_export_runner.dart`, y dos sitios en `vault_session.dart`
  (`exportVaultBackup`, `createPreImportBackupZip`).
- `VaultSession.cloudPackEncryptionKey()` (clave de cifrado del pack para
  libretas sin cifrar) también dependía de `vault.bin` — arreglado igual.
- `VaultSession.cleanupV0AfterSuccessfulSync()`: se llama automáticamente
  tras un sync exitoso a la nube (Firebase incremental, Firebase TAR.GZ) o
  a WebDAV/carpeta local — borra `vault.bin` legacy si sigue en disco y ya
  hay una copia v1 confirmada fuera del dispositivo. P2P no lo dispara (una
  copia en el peer no es un backup duradero).

**Esto no está probado con un sync real contra Firebase** — solo compila y
pasa análisis estático. Antes de confiar en él, hay que probarlo contra un
proyecto Firebase real: subir una libreta v1, bajarla en otro dispositivo/
sesión, confirmar que el contenido es correcto.

## Historial de versiones — el problema que el usuario reporta sin resolver

### Diseño actual (esta sesión, tras dos iteraciones)

1ª iteración: `versionsForPage()` devolvía **todos** los snapshots de la
libreta sin filtrar, y `restoreVersion()` restauraba el árbol **entero**.
El usuario señaló correctamente que esto no es "como git" (el plan original
pedía que el historial fuera por página, con diffs limpios) y que así
restaurar la versión antigua de una página revertiría también ediciones no
relacionadas en otras páginas.

2ª iteración (estado actual del código, sin confirmar si ya está desplegada
en la app que probó el usuario):

- `VaultSnapshotManager.extractFilesFromSnapshot(snapshotId, {paths})`
  (nuevo): abre el `.zip` de un snapshot y extrae solo los archivos pedidos,
  sin descomprimir el árbol completo.
- `VaultSession.versionsForPage(pageId)` (v1): recorre todos los snapshots
  de más antiguo a más reciente, y para cada uno compara el SHA-256 de
  `pages/<id[0:2]>/<id>/meta.json` y `blocks.jsonl` (ya están en el
  `fileManifest` de cada snapshot) contra el snapshot anterior. Solo incluye
  en el resultado los snapshots donde esos hashes cambiaron — es decir,
  donde *esa página concreta* cambió. Debería comportarse como
  `git log -- <path>`.
- `VaultSession.restoreVersion(versionId)` (v1): en vez de restaurar todo
  el árbol, extrae solo `meta.json`+`blocks.jsonl` de esa página desde el
  snapshot (vía `extractFilesFromSnapshot`), y aplica solo `title`+`blocks`
  a esa página en memoria. El resto de páginas no se toca. Antes de
  sobreescribir, crea un snapshot de seguridad del estado actual completo
  (igual que hace v0).
- `lib/features/workspace/history/page_history_sheet.dart`: reescrito de
  `StatelessWidget` a `StatefulWidget` porque `versionsForPage()` es async
  (antes `revisionsForPage()` era síncrono). Para entradas v0 sigue
  mostrando el diff línea a línea (usa `FolioPageRevision` real). Para
  snapshots v1 no hay diff por página disponible (el snapshot no guarda
  contenido "solo de esa página" de forma directa, solo el árbol completo
  en ese momento) — se muestra un aviso en vez de un diff.

### Lo que el usuario vio después de este cambio

Captura de pantalla mostrando "7 versiones" para una página nueva/vacía
("Nueva página"), con la entrada visible siendo literalmente
"Initial snapshot from payload" (la etiqueta que pone
`VaultLocalStorage.decomposeAndStore()` en el snapshot inicial de
migración) — comportamiento que coincide exactamente con lo que hacía el
código **antes** de esta reescritura (mostrar todos los snapshots sin
filtrar), no con el código nuevo.

**No se confirmó la causa antes de que la sesión pasara a este documento.**
Dos hipótesis, en orden de probabilidad según lo revisado:

1. **Build no actualizado.** La app que el usuario está probando lleva
   corriendo toda la sesión (o se reinició sin recompilar de verdad); varias
   veces antes en esta misma sesión el usuario reportó "no funciona" y
   resultó ser que faltaba un `flutter clean && flutter pub get && flutter
   run` completo. El código de `versionsForPage()` fue releído línea por
   línea justo antes de este documento y la lógica de filtrado es correcta
   sobre el papel (compara hashes de `fileManifest` correctamente, itera en
   el orden correcto). Para una página "Nueva" casi vacía, el código nuevo
   debería mostrar 1 versión (la de creación), no 7 — lo cual encaja con
   "está corriendo el código viejo".
2. **Bug real no detectado.** No se descarta al 100%: la lógica nueva
   **no tiene ningún test automatizado que la ejercite end-to-end** (ver
   siguiente sección) — solo se verificó leyendo el código, no
   ejecutándolo. Candidatos a revisar si el rebuild limpio no lo arregla:
   - Que `meta.json` cambie de hash entre snapshots aunque el contenido
     semántico de la página no cambie (p. ej. si algún campo no
     determinista se cuela en la serialización canónica, o si
     `page.properties`/`page.tags` cambian de orden entre llamadas).
   - Que `_snapshotManager.listSnapshots()` no esté devolviendo el
     `fileManifest` completo por algún problema de (de)serialización
     JSON (`vault_snapshot.g.dart`, generado por `json_annotation`).
   - Que el snapshot automático se esté dumpeando en cada pulsación/cambio
     mínimo (no solo cuando el contenido realmente cambió tras el debounce),
     lo que generaría muchos snapshots "reales" que sí cambian el hash de
     `meta.json` cada vez sin que el usuario lo perciba como una edición.

**Primer paso recomendado para quien retome esto**: parar el proceso de la
app por completo, `flutter clean && flutter pub get && flutter run` desde
cero, y repetir la prueba exacta de la captura (página nueva, ver cuántas
versiones aparecen). Si sigue mostrando todas sin filtrar, es la hipótesis
2 y hay que depurar con logs (`AppLogger.info` dentro del bucle de
`versionsForPage()`, imprimiendo hash de cada snapshot) antes de tocar más
código a ciegas.

## Qué está probado y qué no

`flutter analyze lib/` → 0 errores. `flutter test` → 381/381 pasan. Pero:

- **Ningún test de `test/git/` instancia un `VaultSession` real.** El
  archivo `test/git/vault_session_integration_test.dart` dice "Integration"
  en el nombre pero solo usa las piezas de bajo nivel
  (`VaultPayloadToTree`, `VaultSnapshotManager`, etc.) directamente,
  simulando lo que haría `VaultSession` sin llamarlo de verdad. Esto es
  cierto desde antes de esta sesión y no se corrigió — significa que
  `bootstrap()`, `_ensureV1AndLoad()`, `versionsForPage()`,
  `restoreVersion()`, `cleanupV0AfterSuccessfulSync()` y todo lo demás que
  se tocó hoy en `vault_session.dart` **compila pero no tiene cobertura de
  test real**, solo verificación manual leyendo el código.
- Los tests en `test/git/vault_local_storage_test.dart` (nivel
  `VaultSnapshotManager`/`VaultPayloadToTree` directo, sin `VaultSession`)
  sí verifican: SHA-256 real (no placeholder), que el `.zip` de snapshot
  existe con contenido, y que `restoreSnapshot()` (restauración de árbol
  completo) recupera el contenido correcto. **No** hay ningún test para
  `extractFilesFromSnapshot()` (extracción de una sola página) ni para el
  filtrado por página de `versionsForPage()` — se estaba escribiendo uno
  cuando la sesión pasó a este documento, sin terminar.
- Nada de esto se ha probado contra Firebase real (solo mocks/análisis
  estático), ni el flujo completo de migración en la app real más allá de
  lo que el usuario ha ido reportando manualmente.

## Otras cosas encontradas pero no arregladas (fuera de alcance de esta sesión)

- `_parseProperties()` en `vault_payload_converters.dart` pierde las
  `properties` de página en cada round-trip (ver arriba). Bug real,
  probablemente el más grave que queda sin tocar.
- `attachments.manifest.jsonl` en `VaultPayloadToTree._writeAttachmentsManifest()`
  usa un hash falso (`'sha256-todo-${path.hashCode}'`, línea ~221) — mismo
  patrón de placeholder que tenían los snapshots antes de arreglarlos hoy,
  pero para adjuntos. No se tocó.
- `VaultSnapshotManager.deleteSnapshot()` no invalida/recalcula nada más
  (por ejemplo, snapshots posteriores no dependen del contenido del
  borrado, así que esto está bien tal cual, pero no se verificó con test).

## Orden sugerido si otra IA/persona retoma esto

1. Confirmar con un rebuild limpio si el problema del historial de
   versiones es de build o de código (ver sección de arriba).
2. Si es de código: añadir el test que faltaba (crear 2 páginas, editar
   solo una, verificar que `versionsForPage` de la otra no crece) usando un
   `VaultSession` real con un directorio temporal como raíz de libreta —
   esto también cerraría el hueco de cobertura real que tiene todo
   `vault_session.dart` hoy.
3. Arreglar `_parseProperties()` (pérdida de datos real, prioridad alta).
4. Probar el pipeline de cloud-pack reescrito contra un proyecto Firebase
   de pruebas real antes de dar por buena la parte de sync.
