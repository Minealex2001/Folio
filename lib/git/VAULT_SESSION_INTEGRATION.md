# Integración de Snapshots en VaultSession (M2)

## Resumen
Reemplazar el mecanismo de revisiones en memoria (`pageRevisions` en `VaultPayload`) con snapshots persistentes en disco (`<vault>/versions/`).

## Cambios en VaultSession

### 1. Inicialización (en `unlockVault`)

**Antes (viejo formato):**
```dart
// Cargar payload monolítico
final vaultPayload = await _loadVaultPayload();
// pageRevisions están en memoria dentro de _pageRevisions
```

**Después (nuevo formato):**
```dart
// Detectar formato
final formatVersion = await VaultMigrationTool.readTreeFormatVersion();

if (formatVersion == 0) {
  // Formato viejo: cargar como siempre
  final vaultPayload = await _loadVaultPayload();
  // Migrar automáticamente si es necesario (M2+)
  await _autoMigrationIfNeeded();
} else {
  // Formato nuevo: cargar árbol
  final vaultPayload = await VaultLocalStorage.loadFromTree();
  // snapshot manager ya está inicializado en _snapshotManager
}
```

### 2. Campo snapshot manager

**Añadir a VaultSession:**
```dart
late VaultSnapshotManager _snapshotManager;

Future<void> _initSnapshotManager() async {
  final vaultDir = await VaultPaths.vaultDirectory();
  _snapshotManager = VaultSnapshotManager(
    vaultDir: vaultDir,
    deviceId: _deviceId, // deviceId obtenido de device_info o config
  );
  await _snapshotManager.init();
}
```

### 3. Reemplazar `_appendRevisionSnapshotIfChanged`

**Antes:**
```dart
void _appendRevisionSnapshotIfChanged(FolioPage page) {
  final fp = folioPageContentFingerprint(page);
  final list = _pageRevisions.putIfAbsent(page.id, () => []);
  if (list.isNotEmpty && list.last.contentFingerprint() == fp) {
    return;
  }
  list.add(
    FolioPageRevision(
      revisionId: _uuid.v4(),
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
      title: page.title,
      blocksJson: page.blocks.map((b) => b.toJson()).toList(),
    ),
  );
}
```

**Después:**
```dart
Future<void> _createSnapshotIfChanged(FolioPage page) async {
  if (_formatVersion == 0) {
    // Formato viejo: usar revisiones en memoria
    _appendRevisionSnapshotIfChanged(page);
  } else {
    // Formato nuevo: crear snapshot completo del árbol
    // (No per-page, sino del estado global)
    // Esto se llama en _capturePendingRevisionsAndPersist
  }
}
```

### 4. Captura de revisiones (debounce) → Snapshots

**Antes:**
```dart
Future<void> _capturePendingRevisionsAndPersist() async {
  if (vaultUsesEncryption && _dek == null) return;
  final ids = List<String>.from(_pageIdsPendingRevision);
  _pageIdsPendingRevision.clear();
  for (final id in ids) {
    final p = _pageById(id);
    if (p != null) {
      _appendRevisionSnapshotIfChanged(p);
    }
  }
  await persistNow();
}
```

**Después (M2):**
```dart
Future<void> _capturePendingRevisionsAndPersist() async {
  if (vaultUsesEncryption && _dek == null) return;
  final ids = List<String>.from(_pageIdsPendingRevision);
  _pageIdsPendingRevision.clear();
  
  if (_formatVersion == 0) {
    // Formato viejo: capturar revisiones por página
    for (final id in ids) {
      final p = _pageById(id);
      if (p != null) {
        _appendRevisionSnapshotIfChanged(p);
      }
    }
  } else {
    // Formato nuevo: crear snapshot del árbol completo si algo cambió
    if (ids.isNotEmpty) {
      await _createVaultSnapshot();
    }
  }
  
  await persistNow();
}

Future<void> _createVaultSnapshot() async {
  try {
    final treeDir = await VaultPaths.vaultTreeDirectory();
    // El árbol ya está serializado en disk por persistNow()
    // Solo crear metadatos del snapshot
    await _snapshotManager.createSnapshot(
      treeDir: treeDir,
      label: null, // Auto-labeled con timestamp
    );
  } catch (e) {
    // Log but don't fail persistence
    AppLogger.instance.warning('Failed to create snapshot: $e');
  }
}
```

### 5. Persistencia (serializar árbol)

**Antes:**
```dart
Future<void> persistNow() async {
  // ... 
  final payload = _buildVaultPayloadForPersist();
  await _persistPayload(payload); // Escribe vault.bin monolítico
}
```

**Después (M2):**
```dart
Future<void> persistNow() async {
  if (_formatVersion == 0) {
    // Formato viejo: persistir payload monolítico
    final payload = _buildVaultPayloadForPersist();
    await _persistPayload(payload);
  } else {
    // Formato nuevo: deserializar árbol del payload
    final payload = _buildVaultPayloadForPersist();
    final treeDir = await VaultPaths.vaultTreeDirectory();
    await VaultPayloadToTree.decompose(payload, treeDir);
    // Nota: no guardamos pageRevisions en el árbol
    // (están en snapshots ahora)
  }
}
```

### 6. Historial de versiones (UI)

**Antes:**
```dart
List<FolioPageRevision> revisionsForPage(String pageId) {
  final list = _pageRevisions[pageId];
  if (list == null || list.isEmpty) return const [];
  return list..sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs));
}
```

**Después (M2):**
```dart
Future<List<VersionInfo>> versionsForPage(String pageId) async {
  if (_formatVersion == 0) {
    // Formato viejo: leer de _pageRevisions
    return revisionsForPage(pageId)
      .map((r) => VersionInfo(
        id: r.revisionId,
        timestamp: r.savedAtMs,
        title: r.title,
        source: 'memory', // en el árbol, será 'snapshot'
      ))
      .toList();
  } else {
    // Formato nuevo: leer snapshots del disco
    final snapshots = await _snapshotManager.listSnapshots();
    // Mapear a VersionInfo para UI
    return snapshots
      .map((s) => VersionInfo(
        id: s.snapshotId,
        timestamp: s.createdAtMs,
        title: s.label ?? 'Snapshot at ${DateTime.fromMillisecondsSinceEpoch(s.createdAtMs)}',
        source: 'snapshot',
      ))
      .toList();
  }
}
```

### 7. Restauración de versiones

**Antes:**
```dart
void restorePageRevision(String pageId, String revisionId) {
  final target = _pageRevisions[pageId]?.firstWhere((r) => r.revisionId == revisionId);
  page.title = target.title;
  page.blocks = target.decodeBlocks();
  // ...
}
```

**Después (M2):**
```dart
Future<bool> restoreVersion(String versionId) async {
  if (_formatVersion == 0) {
    // Formato viejo: restaurar desde pageRevisions
    // (código existente)
    return true;
  } else {
    // Formato nuevo: restaurar desde snapshot
    final targetTreeDir = Directory.systemTemp.createTempSync('restore_');
    final success = await _snapshotManager.restoreSnapshot(versionId, targetTreeDir);
    if (!success) {
      targetTreeDir.deleteSync(recursive: true);
      return false;
    }

    // Recompose árbol
    final payload = await TreeToVaultPayload.compose(targetTreeDir);
    
    // Crear backup del estado actual
    await _createVaultSnapshot();
    
    // Cargar payload restaurado
    _pages = payload.pages;
    _pageOrderByParent = payload.pageOrderByParent;
    _contentEpoch++;
    notifyListeners();
    
    await persistNow();
    targetTreeDir.deleteSync(recursive: true);
    return true;
  }
}
```

## Campos a añadir a VaultSession

```dart
class VaultSession extends ChangeNotifier {
  // ...
  
  /// Formato de vault: 0 = viejo (monolítico), 1 = nuevo (árbol)
  int _formatVersion = 0;
  
  /// Gestor de snapshots (solo usado si _formatVersion == 1)
  late VaultSnapshotManager _snapshotManager;
  
  /// Device ID para snapshots (obtenido de device_info)
  String _deviceId = 'unknown-device';
  
  // ...
}
```

## Migración automática (Opt-in en M2)

En `unlockVault()`, después de cargar el payload:

```dart
if (_formatVersion == 0) {
  // Preguntar al usuario si quiere migrar
  // O detectar si está en dispositivo primario
  final shouldMigrate = await _shouldAutoMigrate();
  if (shouldMigrate) {
    AppLogger.instance.info('Auto-migrating vault to new format...');
    await VaultMigrationTool.migrateVault(
      payload: _payload,
      deviceId: _deviceId,
    );
    _formatVersion = 1;
    await _initSnapshotManager();
  }
}
```

## Orden de operaciones en persistencia

1. **Load:** detect formatVersion → init snapshot manager si v1
2. **Edit:** crear snapshots en debounce idle (ya implementado)
3. **Persist:** serializar árbol si v1, o payload si v0
4. **Restore:** restaurar desde snapshots si v1, o pageRevisions si v0

## Consideraciones de seguridad

- **Backups:** rollback() restaura desde vault.bin.bak
- **Coordinación:** treeFormatVersion marker evita migraciones duplicadas
- **Rollback:** si falla migración, revertir a v0 es posible
- **Tests:** validar round-trip completo (cargar, editar, snapshot, restaurar)
