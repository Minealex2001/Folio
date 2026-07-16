import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/vault_payload.dart';

/// Estado visible del guardado en disco.
enum SaveStatus { idle, pending, saving, saved, error }

/// Controla debounce, flush y persistencia de la libreta.
class VaultPersistenceController extends ChangeNotifier {
  VaultPersistenceController({
    required VaultPayload Function() buildPayload,
    required Future<void> Function(VaultPayload payload) savePayload,
    required bool Function() canPersist,
    this.onPersisted,
    Duration debounce = const Duration(milliseconds: 450),
  }) : _buildPayload = buildPayload,
       _savePayload = savePayload,
       _canPersist = canPersist,
       _debounce = debounce;

  final VaultPayload Function() _buildPayload;
  final Future<void> Function(VaultPayload payload) _savePayload;
  final bool Function() _canPersist;
  final Duration _debounce;

  void Function()? onPersisted;

  Timer? _saveDebounce;
  Future<void>? _activeWrite;
  int _persistDepth = 0;
  int _suppressPersistedCallbackDepth = 0;
  SaveStatus _status = SaveStatus.idle;
  final List<void Function()> _pendingFlushHooks = [];

  SaveStatus get status => _status;
  bool get hasPendingDiskSave => _saveDebounce != null;
  bool get isPersistingToDisk => _persistDepth > 0;

  void addPendingFlushHook(void Function() hook) {
    if (!_pendingFlushHooks.contains(hook)) _pendingFlushHooks.add(hook);
  }

  void removePendingFlushHook(void Function() hook) {
    _pendingFlushHooks.remove(hook);
  }

  void _runPendingFlushHooks() {
    for (final hook in List<void Function()>.from(_pendingFlushHooks)) {
      try {
        hook();
      } catch (e) {
        debugPrint('[vault] pending flush hook failed: $e');
      }
    }
  }

  void scheduleSave() {
    if (!_canPersist()) return;
    _saveDebounce?.cancel();
    _status = SaveStatus.pending;
    notifyListeners();
    _saveDebounce = Timer(_debounce, () {
      _saveDebounce = null;
      unawaited(persistNow());
    });
  }

  Future<void> flushPendingSave() async {
    _runPendingFlushHooks();
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _saveDebounce = null;
      await persistNow();
    }
  }

  Future<void> persistNow() async {
    if (!_canPersist()) return;
    // Mutex de escritura: solo una escritura a disco a la vez. Los llamadores
    // concurrentes esperan y luego reconstruyen el payload con el estado más
    // reciente, evitando last-write-wins con estados intermedios.
    while (_activeWrite != null) {
      try {
        await _activeWrite;
      } catch (_) {
        // El error pertenece al llamador original; aquí solo esperamos turno.
      }
    }
    final write = _doPersist();
    _activeWrite = write;
    try {
      await write;
    } finally {
      if (identical(_activeWrite, write)) _activeWrite = null;
    }
  }

  Future<void> _doPersist() async {
    if (!_canPersist()) return;
    var persisted = false;
    _persistDepth++;
    if (_persistDepth == 1) {
      _status = SaveStatus.saving;
      notifyListeners();
    }
    try {
      await _savePayload(_buildPayload());
      persisted = true;
      _status = SaveStatus.saved;
    } catch (e) {
      _status = SaveStatus.error;
      rethrow;
    } finally {
      _persistDepth--;
      if (_persistDepth == 0) {
        notifyListeners();
      }
    }
    if (persisted && _suppressPersistedCallbackDepth == 0) {
      try {
        onPersisted?.call();
      } catch (_) {}
    }
  }

  Future<void> persistNowSuppressed() async {
    _suppressPersistedCallbackDepth++;
    try {
      await persistNow();
    } finally {
      _suppressPersistedCallbackDepth--;
    }
  }

  void cancelPendingSave() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (_status == SaveStatus.pending) {
      _status = SaveStatus.idle;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    super.dispose();
  }
}
