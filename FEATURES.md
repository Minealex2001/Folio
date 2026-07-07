# Folio — Features técnicas

## Refuerzo de base (v0.5.x)

### Escritura atómica de libreta

- Archivos críticos (`vault.bin`, `vault.keys`, `vault.mode`) se escriben con patrón **tmp → flush → rotar `.bak` → rename**.
- Implementación: [`lib/data/storage/atomic_file_writer.dart`](lib/data/storage/atomic_file_writer.dart), usada desde [`lib/data/storage/vault_storage_io.dart`](lib/data/storage/vault_storage_io.dart).

### Migración de esquema `VaultPayload`

- Migrador central en [`lib/domain/vault/vault_migration.dart`](lib/domain/vault/vault_migration.dart).
- Se ejecuta en [`VaultRepository.loadPayload`](lib/data/vault_repository.dart) tras decodificar.
- Si `vault.bin` está corrupto, se intenta `vault.bin.bak` antes de lanzar `VaultCorruptionException`.

### Modo recuperación

- Nuevo estado `VaultFlowState.recovery` y pantalla [`lib/features/vault/recovery_screen.dart`](lib/features/vault/recovery_screen.dart).
- Acciones: restaurar `.bak`, importar ZIP, exportar copia de emergencia, abrir carpeta de datos.

### Arranque por fases

- [`lib/core/bootstrap/app_bootstrap.dart`](lib/core/bootstrap/app_bootstrap.dart) separa:
  - **Fase crítica**: registro + `session.bootstrap()` (bloquea UI hasta resolver).
  - **Fases secundarias**: sync, IA, integraciones, desktop, backups (degradan sin impedir abrir).
- Integrado en [`lib/app/folio_app.dart`](lib/app/folio_app.dart).

### Guardado y feedback

- [`VaultPersistenceController`](lib/application/vault_persistence_controller.dart): debounce, flush, `SaveStatus`.
- Chip de estado en workspace: [`lib/features/workspace/shell/save_status_chip.dart`](lib/features/workspace/shell/save_status_chip.dart) con `ListenableBuilder` (no rebuild del editor).
- `onAppBackgrounded` siempre llama a `flushPendingSave()` antes de bloquear.

### Backup pre-importación

- `createPreImportBackupZip()` en [`lib/data/vault_backup.dart`](lib/data/vault_backup.dart).
- Se invoca antes de importaciones destructivas (p. ej. Notion → libreta actual).

### Controllers de aplicación

- [`PageTreeController`](lib/application/page_tree_controller.dart): árbol de páginas.
- [`VaultAiController`](lib/application/vault_ai_controller.dart): estado de chats IA.
- [`VaultSyncController`](lib/application/vault_sync_controller.dart): conflictos/sync (base para extracción).
- `VaultSession` compone controllers y mantiene API pública.

### Riverpod (piloto)

- `ProviderScope` en `FolioApp` con providers en [`lib/app/folio_providers.dart`](lib/app/folio_providers.dart):
  - `vaultFlowStateProvider`, `selectedPageProvider`, `saveStatusProvider`, `vaultSessionProvider`.

### Índice de búsqueda

- [`VaultSearchIndex`](lib/application/vault_search_index.dart): índice en memoria + `search_index.json` regenerable en carpeta de libreta.
- `VaultSession.searchGlobal` usa el índice cuando está construido.

### Drift (evaluación, no implementado)

- Recomendación documentada en `DriftCacheEvaluation` dentro de `vault_search_index.dart`:
  - Mantener `vault.bin` como fuente de verdad.
  - Introducir Drift solo si métricas de beta justifican FTS/backlinks en libretas grandes (>500 páginas, búsqueda >200 ms).
  - Usarlo como **caché de lectura** desencriptada regenerable, no como reemplazo del blob cifrado.

### Build Windows

- `install(DIRECTORY native_assets/windows/)` fallaba en el paso **INSTALL** cuando el directorio no existía (build debug sin native assets).
- Fix en [`windows/CMakeLists.txt`](windows/CMakeLists.txt): copia condicional solo si `native_assets/windows/` existe.
- `lib/config/folio_local_secrets.dart` deja de estar en `.gitignore`; se versiona con valores vacíos (sobrescribir localmente o usar `--dart-define` para secretos reales).
- Tras apagados inesperados durante compilación MSVC, usar `$env:CMAKE_BUILD_PARALLEL_LEVEL = "2"` antes de `flutter build windows`.
