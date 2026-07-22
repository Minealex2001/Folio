# Implementación en vault_session.dart — M5 (Línea por Línea)

## Estado Actual (hecho)
✅ Campos agregados (línea ~412-415)
✅ Imports agregados (línea ~84-90)

## Cambios Pendientes

### 1. En `bootstrap()` — Inicializar formatHandler y deviceId

**Ubicación**: Línea ~860-925 (método bootstrap)

**Agregar después de línea 884** (`await _rp.loadFromDisk();`):

```dart
    // M5: Initialize format handler
    _deviceId = await _getDeviceId();
    _formatHandler = VaultFormatHandler(
      deviceId: _deviceId,
      onMigrationNeeded: _triggerMigrationPrompt,
    );
    _vaultFormatVersion = await _formatHandler.detectFormat();
```

**Modificar línea 898** (donde carga payload para plaintext):

Cambiar:
```dart
          final payload = await _repo.loadPayload(null);
```

A:
```dart
          VaultPayload payload;
          if (_vaultFormatVersion == 0) {
            payload = await _repo.loadPayload(null);
          } else {
            // Format v1: load from tree
            final loaded = await _formatHandler.loadPayload(_vaultFormatVersion);
            payload = loaded ?? (await _repo.loadPayload(null))!;
          }
```

**Después de línea 907** (después de `_restartIdleLockTimer();`), agregar:

```dart
          // M5: Init snapshot manager for v1
          if (_vaultFormatVersion == 1) {
            final vaultDir = await VaultPaths.vaultDirectory();
            _snapshotManager = VaultSnapshotManager(
              vaultDir: vaultDir,
              deviceId: _deviceId,
            );
            await _snapshotManager.init();
          }
```

### 2. En `_capturePendingRevisionsAndPersist()` — Crear snapshots en v1

**Ubicación**: Línea ~5682-5691

**Reemplazar todo el método** con:

```dart
  Future<void> _capturePendingRevisionsAndPersist() async {
    if (vaultUsesEncryption && _dek == null) return;
    final ids = List<String>.from(_pageIdsPendingRevision);
    _pageIdsPendingRevision.clear();
    
    if (ids.isEmpty) {
      await persistNow();
      return;
    }
    
    if (_vaultFormatVersion == 0) {
      // Format v0: capture page revisions to memory
      for (final id in ids) {
        final p = _pageById(id);
        if (p != null) {
          _appendRevisionSnapshotIfChanged(p);
        }
      }
    }
    // Format v1: snapshot will be created in persistNow()
    
    await persistNow();
  }
```

### 3. En `persistNow()` — Serializar a árbol (v1) o vault.bin (v0)

**Ubicación**: Línea ~5805-5806

**Reemplazar** (`await _persistence.persistNow();`) con:

```dart
  Future<void> persistNow() async {
    if (_vaultFormatVersion == 0) {
      // Format v0: persist to vault.bin (existing)
      await _persistence.persistNow();
    } else {
      // Format v1: decompose to tree + create snapshot
      try {
        final payload = _buildVaultPayloadForPersist();
        await VaultLocalStorage.decomposeAndStore(
          payload,
          deviceId: _deviceId,
        );
        
        // Create snapshot after persist
        await _createVaultSnapshotSafe();
      } catch (e) {
        AppLogger.instance.error('Failed to persist v1 vault: $e');
        rethrow;
      }
    }
  }

  Future<void> _createVaultSnapshotSafe() async {
    if (_vaultFormatVersion != 1) return;
    try {
      final treeDir = await VaultPaths.vaultTreeDirectory();
      await _snapshotManager.createSnapshot(
        treeDir: treeDir,
        label: null, // Auto-labeled
      );
    } catch (e) {
      AppLogger.instance.warning('Snapshot creation failed: $e');
      // Don't fail persistence
    }
  }
```

### 4. En `revisionsForPage()` — Renombrar a `versionsForPage()`

**Ubicación**: Línea ~5712-5716

**Agregar nuevo método** después de `revisionsForPage()`:

```dart
  Future<List<VersionInfo>> versionsForPage(String pageId) async {
    if (_vaultFormatVersion == 0) {
      // Format v0: return from memory
      final list = _pageRevisions[pageId];
      if (list == null || list.isEmpty) return [];
      return list
          .map((r) => VersionInfo(
            versionId: r.revisionId,
            timestamp: r.savedAtMs,
            label: r.title,
            source: 'memory',
          ))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      // Format v1: return snapshots
      final snapshots = await VaultLocalStorage.listSnapshots();
      return snapshots
          .map((s) => VersionInfo(
            versionId: s.snapshotId,
            timestamp: s.createdAtMs,
            label: s.displayLabel,
            source: 'snapshot',
            deviceId: s.deviceId,
          ))
          .toList();
    }
  }
```

### 5. En `restorePageRevision()` — Agregar método `restoreVersion()`

**Ubicación**: Línea ~5734-5761

**Agregar nuevo método** después de `restorePageRevision()`:

```dart
  Future<bool> restoreVersion(String versionId) async {
    if (vaultUsesEncryption && _dek == null) return false;
    
    if (_vaultFormatVersion == 0) {
      // Format v0: restore from pageRevisions
      final page = _pageById(_selectedPageId ?? '');
      if (page == null) return false;
      
      final list = _pageRevisions[page.id];
      if (list == null) return false;
      
      final target = list.firstWhereOrNull((r) => r.revisionId == versionId);
      if (target == null) return false;
      
      // Backup current state
      final curFp = folioPageContentFingerprint(page);
      final revs = _pageRevisions.putIfAbsent(page.id, () => []);
      if (revs.isEmpty || revs.last.contentFingerprint() != curFp) {
        revs.add(
          FolioPageRevision(
            revisionId: const Uuid().v4(),
            savedAtMs: DateTime.now().millisecondsSinceEpoch,
            title: page.title,
            blocksJson: page.blocks.map((b) => b.toJson()).toList(),
          ),
        );
      }
      
      // Restore
      page.title = target.title;
      page.blocks = target.decodeBlocks();
      _contentEpoch++;
      notifyListeners();
      await persistNow();
      return true;
    } else {
      // Format v1: restore from snapshot (M2+, not in M5 alpha)
      AppLogger.instance.warning('Snapshot restore not yet implemented');
      return false;
    }
  }
```

### 6. Helpers

**Agregar al final de la clase** (antes del cierre):

```dart
  Future<String> _getDeviceId() async {
    try {
      // TODO: Use device_info_plus when available
      // For now, use device name or fixed string
      return Platform.localHostname;
    } catch (_) {
      return 'unknown-device';
    }
  }

  Future<void> _triggerMigrationPrompt(String vaultId) async {
    // Called by VaultFormatHandler when migration is needed
    // Show dialog to user in the UI layer
    AppLogger.instance.info('Migration available for vault $vaultId');
    // TODO: Show migration prompt dialog
  }
```

## Orden de Implementación

1. **Fase 1** (Ya hecho):
   - ✅ Agregar campos
   - ✅ Agregar imports

2. **Fase 2** (Este documento):
   - Modificar `bootstrap()` para inicializar formatHandler
   - Reemplazar `_capturePendingRevisionsAndPersist()`
   - Reemplazar `persistNow()`
   - Agregar `versionsForPage()`
   - Agregar `restoreVersion()`
   - Agregar helpers

3. **Fase 3** (Testing):
   - Ejecutar tests existentes
   - Agregar tests de integración v0/v1

## Líneas Exactas (para Ctrl+G en editor)

| Cambio | Línea Aproximada | Método |
|--------|-----------------|--------|
| Init formatHandler | 885 | bootstrap() |
| Load payload v1 | 898 | bootstrap() |
| Init snapshot manager | 908 | bootstrap() |
| _capturePendingRevisionsAndPersist | 5682 | _capturePendingRevisionsAndPersist() |
| persistNow | 5805 | persistNow() |
| versionsForPage | 5720 | (nuevo, después de revisionsForPage) |
| restoreVersion | 5762 | (nuevo, después de restorePageRevision) |
| Helpers | EOF | (al final) |

## Testing

Después de implementar, ejecutar:

```bash
flutter test test/git/vault_session_integration_test.dart
```

Debe pasar todos los 8 tests de integración.

## Verificación

- [ ] Código compila sin errores
- [ ] Detecta v0 y v1 correctly
- [ ] Carga payload diferente según versión
- [ ] Crea snapshots en v1
- [ ] Historial funciona ambos formatos
- [ ] Persiste a vault.bin (v0) o árbol (v1)
- [ ] Tests pasan
