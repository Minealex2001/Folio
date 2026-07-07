import 'package:flutter/foundation.dart';

import '../session/vault_session.dart';

/// Conflictos y snapshots de sincronización entre dispositivos.
class VaultSyncController extends ChangeNotifier {
  VaultSyncController({
    required Future<List<int>?> Function() exportSnapshot,
    required Future<bool> Function(List<int> bytes, String fromPeerId)
    applySnapshot,
    required void Function(int count) onConflictCountChanged,
  }) : _exportSnapshot = exportSnapshot,
       _applySnapshot = applySnapshot,
       _onConflictCountChanged = onConflictCountChanged;

  final Future<List<int>?> Function() _exportSnapshot;
  final Future<bool> Function(List<int> bytes, String fromPeerId) _applySnapshot;
  final void Function(int count) _onConflictCountChanged;

  final List<SyncConflictEntry> _conflicts = [];
  String _baselineFingerprint = '';

  List<SyncConflictEntry> get conflicts => List.unmodifiable(_conflicts);
  int get pendingConflicts => _conflicts.length;
  String get baselineFingerprint => _baselineFingerprint;

  void setBaselineFingerprint(String value) {
    _baselineFingerprint = value;
  }

  void addConflict(SyncConflictEntry entry) {
    if (_conflicts.any((c) => c.remoteFingerprint == entry.remoteFingerprint)) {
      return;
    }
    _conflicts.add(entry);
    _onConflictCountChanged(_conflicts.length);
    notifyListeners();
  }

  void clearConflicts() {
    if (_conflicts.isEmpty) return;
    _conflicts.clear();
    _onConflictCountChanged(0);
    notifyListeners();
  }

  Future<List<int>?> exportSnapshotBytes() => _exportSnapshot();

  Future<bool> applySnapshotBytes(List<int> bytes, [String fromPeerId = '']) =>
      _applySnapshot(bytes, fromPeerId);
}
