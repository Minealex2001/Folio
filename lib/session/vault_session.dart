import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'package:uuid/uuid.dart';

import '../data/vault_backup.dart';
import '../data/vault_paths.dart';
import '../data/vault_payload.dart';
import '../data/vault_registry.dart';
import '../data/vault_repository.dart';
import '../models/block.dart';
import '../models/folio_page.dart';
import '../models/folio_page_revision.dart';
import '../models/folio_table_data.dart';
import '../services/folio_rp_server.dart';
import '../services/quick_unlock_storage.dart';

enum VaultFlowState { initializing, needsOnboarding, locked, unlocked }

class VaultSession extends ChangeNotifier {
  bool _isManagedAttachmentPath(String? path) {
    final p = path?.trim();
    return p != null && p.startsWith('${VaultPaths.attachmentsDirName}/');
  }

  Iterable<String> _managedAttachmentPathsOfBlock(FolioBlock b) sync* {
    if (b.type == 'image' && _isManagedAttachmentPath(b.text)) {
      yield b.text.trim();
    }
    if ((b.type == 'file' || b.type == 'video') && _isManagedAttachmentPath(b.url)) {
      yield b.url!.trim();
    }
  }

  bool _isAttachmentReferencedAnywhere(
    String relativePath, {
    String? excludingPageId,
    String? excludingBlockId,
  }) {
    final target = relativePath.trim();
    if (target.isEmpty) return false;

    for (final p in _pages) {
      for (final b in p.blocks) {
        if (excludingPageId == p.id && excludingBlockId == b.id) {
          continue;
        }
        if (_managedAttachmentPathsOfBlock(b).contains(target)) {
          return true;
        }
      }
    }

    for (final entry in _pageRevisions.entries) {
      for (final rev in entry.value) {
        for (final bj in rev.blocksJson) {
          final b = FolioBlock.fromJson(bj);
          if (_managedAttachmentPathsOfBlock(b).contains(target)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _deleteManagedAttachmentIfUnused(
    String relativePath, {
    String? excludingPageId,
    String? excludingBlockId,
  }) {
    if (!_isManagedAttachmentPath(relativePath)) return;
    final inUse = _isAttachmentReferencedAnywhere(
      relativePath,
      excludingPageId: excludingPageId,
      excludingBlockId: excludingBlockId,
    );
    if (!inUse) {
      unawaited(VaultPaths.deleteAttachmentIfExists(relativePath));
    }
  }

  VaultSession({
    VaultRepository? repository,
    QuickUnlockStorage? quickUnlock,
    FolioRpServer? rpServer,
    PasskeyAuthenticator? passkeys,
    LocalAuthentication? localAuth,
  }) : _repo = repository ?? VaultRepository(),
       _quick = quickUnlock ?? QuickUnlockStorage(),
       _rp = rpServer ?? FolioRpServer(),
       _passkeys = passkeys ?? PasskeyAuthenticator(),
       _localAuth = localAuth ?? LocalAuthentication();

  final VaultRepository _repo;
  final QuickUnlockStorage _quick;
  final FolioRpServer _rp;
  final PasskeyAuthenticator _passkeys;
  final LocalAuthentication _localAuth;

  static const _uuid = Uuid();

  VaultFlowState _state = VaultFlowState.initializing;
  List<int>? _dek;
  List<FolioPage> _pages = [];

  /// Historial de revisiones por `pageId` (orden cronológico ascendente).
  final Map<String, List<FolioPageRevision>> _pageRevisions = {};
  String? _selectedPageId;
  Timer? _saveDebounce;
  Timer? _revisionIdleTimer;
  final Set<String> _pageIdsPendingRevision = {};
  int _persistDepth = 0;

  /// Tras "Añadir cofre", se restaura al cancelar onboarding.
  String? _resumeVaultIdAfterNewVault;

  final VaultRegistry _registry = VaultRegistry.instance;

  String? get activeVaultId => VaultPaths.activeVaultId;

  bool get canCancelNewVaultOnboarding => _resumeVaultIdAfterNewVault != null;

  Future<List<VaultEntry>> listVaultEntries() async {
    await _registry.load();
    return _registry.vaults;
  }

  String? get _vaultId => VaultPaths.activeVaultId;

  /// Tras dejar de editar, se crea una entrada de historial (además del guardado rápido).
  static const Duration _revisionIdleDelay = Duration(milliseconds: 2500);

  /// Hay un guardado al disco programado (debounce) y aún no se ha ejecutado.
  bool get hasPendingDiskSave => _saveDebounce != null;

  /// Escritura cifrada del cofre en curso (puede anidarse si varias rutas llaman a [persistNow]).
  bool get isPersistingToDisk => _persistDepth > 0;

  VaultFlowState get state => _state;
  List<FolioPage> get pages => List.unmodifiable(_pages);
  String? get selectedPageId => _selectedPageId;

  /// Se incrementa al restaurar una revisión para forzar remount del editor
  /// cuando los ids de bloque coinciden pero el texto cambió.
  int get contentEpoch => _contentEpoch;
  int _contentEpoch = 0;

  FolioPage? get selectedPage {
    if (_selectedPageId == null) return null;
    try {
      return _pages.firstWhere((p) => p.id == _selectedPageId);
    } catch (_) {
      return null;
    }
  }

  FolioRpServer get rpServer => _rp;

  Future<bool> get quickUnlockEnabled async {
    final id = _vaultId;
    if (id == null) return false;
    return _quick.isEnabled(id);
  }

  Future<bool> get hasPasskey async {
    await _rp.loadFromDisk();
    return _rp.hasPasskey;
  }

  FolioPage? _pageById(String id) {
    for (final p in _pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  FolioBlock? _blockById(FolioPage page, String blockId) {
    for (final b in page.blocks) {
      if (b.id == blockId) return b;
    }
    return null;
  }

  Future<void> bootstrap() async {
    _state = VaultFlowState.initializing;
    notifyListeners();

    await _registry.migrateFromLegacyIfNeeded();
    await _registry.load();

    if (_registry.vaults.isEmpty) {
      VaultPaths.clearActiveVaultId();
      _dek = null;
      _pages = [];
      _selectedPageId = null;
      _state = VaultFlowState.needsOnboarding;
      notifyListeners();
      return;
    }

    var active = _registry.activeVaultId;
    if (active == null || !_registry.containsVault(active)) {
      active = _registry.vaults.first.id;
      await _registry.setActiveVaultId(active);
    }
    VaultPaths.setActiveVaultId(active);

    await _rp.loadFromDisk();

    final exists = await VaultPaths.vaultExists();
    if (!exists) {
      _dek = null;
      _pages = [];
      _selectedPageId = null;
      _state = VaultFlowState.needsOnboarding;
    } else {
      _state = VaultFlowState.locked;
      _dek = null;
    }
    notifyListeners();
  }

  void _loadRevisionsFromPayload(VaultPayload payload) {
    _pageRevisions
      ..clear()
      ..addEntries(
        payload.pageRevisions.entries.map(
          (e) => MapEntry(e.key, List<FolioPageRevision>.from(e.value)),
        ),
      );
  }

  Future<void> completeOnboarding(String password) async {
    await _registry.load();
    var id = VaultPaths.activeVaultId;
    if (id == null) {
      id = _uuid.v4();
      VaultPaths.setActiveVaultId(id);
    }
    await VaultPaths.vaultDirectoryForId(id);
    if (!_registry.containsVault(id)) {
      final ordinal = _registry.vaults.length + 1;
      await _registry.add(
        VaultEntry(
          id: id,
          displayName: 'Cofre $ordinal',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    await _registry.setActiveVaultId(id);

    _dek = (await _repo.createVault(password: password)).toList();
    final payload = await _repo.loadPayload(_dek!);
    _pages = List.from(payload.pages);
    _loadRevisionsFromPayload(payload);
    _pickInitialSelection();
    _state = VaultFlowState.unlocked;
    _resumeVaultIdAfterNewVault = null;
    notifyListeners();
    await persistNow();
  }

  /// Añade un cofre vacío y pasa a onboarding (el usuario debe completar contraseña o import).
  Future<void> prepareNewVault() async {
    await _registry.load();
    final current = VaultPaths.activeVaultId;
    if (current == null) {
      throw StateError('No hay cofre activo');
    }
    _resumeVaultIdAfterNewVault = current;
    final newId = _uuid.v4();
    VaultPaths.setActiveVaultId(newId);
    await _registry.setActiveVaultId(newId);
    lock();
    await bootstrap();
  }

  /// Cancela el onboarding de un cofre nuevo y vuelve al cofre anterior.
  Future<void> cancelPrepareNewVault() async {
    final resume = _resumeVaultIdAfterNewVault;
    if (resume == null) return;
    final cur = VaultPaths.activeVaultId;
    if (cur != null && !await VaultPaths.vaultExistsForId(cur)) {
      await VaultPaths.deleteVaultDirectory(cur);
    }
    VaultPaths.setActiveVaultId(resume);
    await _registry.setActiveVaultId(resume);
    _resumeVaultIdAfterNewVault = null;
    await bootstrap();
  }

  Future<void> switchVault(String vaultId) async {
    await _registry.load();
    if (!_registry.containsVault(vaultId)) return;
    lock();
    VaultPaths.setActiveVaultId(vaultId);
    await _registry.setActiveVaultId(vaultId);
    _resumeVaultIdAfterNewVault = null;
    await bootstrap();
  }

  Future<void> renameActiveVault(String displayName) async {
    final id = _vaultId;
    if (id == null) return;
    await _registry.rename(id, displayName);
    notifyListeners();
  }

  /// Elimina otro cofre (no el activo). Requiere que no sea el abierto.
  Future<void> deleteVaultById(String vaultId) async {
    await _registry.load();
    if (vaultId == VaultPaths.activeVaultId) {
      throw StateError(
        'No se puede borrar el cofre activo desde aquí; usa Borrar cofre.',
      );
    }
    if (!_registry.containsVault(vaultId)) return;
    await _quick.disable(vaultId);
    await VaultPaths.deleteVaultDirectory(vaultId);
    await _registry.remove(vaultId);
    notifyListeners();
  }

  /// La UI debe haber verificado la identidad del cofre **actual** (contraseña / Hello / passkey).
  /// [zipPath] ruta del `.zip` a crear.
  Future<void> exportVaultBackup(String zipPath) async {
    await persistNow();
    await exportVaultZip(File(zipPath));
  }

  /// Importa el ZIP como **cofre nuevo**; el cofre activo no se modifica.
  /// Devuelve el id del cofre creado.
  Future<String> importVaultBackupAsNew(
    String zipPath,
    String backupPassword, {
    String? displayName,
  }) async {
    final temp = Directory.systemTemp.createTempSync('folio_import_new_');
    try {
      await extractBackupZipToDirectory(File(zipPath), temp);
      await validateImportZip(temp, backupPassword);
      final newId = _uuid.v4();
      final root = await VaultPaths.vaultDirectoryForId(newId);
      await applyImportToVaultRoot(temp, root);
      await _registry.load();
      await _registry.add(
        VaultEntry(
          id: newId,
          displayName: displayName ?? 'Cofre importado',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      notifyListeners();
      return newId;
    } finally {
      try {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Onboarding por copia: escribe el cofre en el id activo (o nuevo) y registra.
  Future<void> completeOnboardingFromBackup(
    String zipPath,
    String backupPassword,
  ) async {
    await _registry.load();
    if (VaultPaths.activeVaultId != null && await VaultPaths.vaultExists()) {
      throw StateError('Ya hay datos en el cofre actual.');
    }
    final temp = Directory.systemTemp.createTempSync('folio_onboard_import_');
    try {
      await extractBackupZipToDirectory(File(zipPath), temp);
      await validateImportZip(temp, backupPassword);

      var id = VaultPaths.activeVaultId;
      if (id == null) {
        id = _uuid.v4();
        VaultPaths.setActiveVaultId(id);
      }
      final root = await VaultPaths.vaultDirectoryForId(id);
      await applyImportToVaultRoot(temp, root);

      if (!_registry.containsVault(id)) {
        final ordinal = _registry.vaults.length + 1;
        await _registry.add(
          VaultEntry(
            id: id,
            displayName: 'Cofre $ordinal',
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      await _registry.setActiveVaultId(id);

      await unlockWithPassword(backupPassword);
      _resumeVaultIdAfterNewVault = null;
    } finally {
      try {
        if (temp.existsSync()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<void> unlockWithPassword(String password) async {
    final dek = await _repo.unlockWithPassword(password);
    _dek = dek.toList();
    final payload = await _repo.loadPayload(_dek!);
    _pages = List.from(payload.pages);
    _loadRevisionsFromPayload(payload);
    _pickInitialSelection();
    _state = VaultFlowState.unlocked;
    notifyListeners();
  }

  Future<void> unlockWithDeviceAuth() async {
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) {
      throw StateError('Este dispositivo no admite biometría o Windows Hello');
    }
    final ok = await _localAuth.authenticate(
      localizedReason: 'Desbloquea Folio para acceder a tus notas cifradas',
    );
    if (!ok) {
      throw StateError('Autenticación cancelada');
    }
    final vid = _vaultId;
    if (vid == null) {
      throw StateError('No hay cofre activo');
    }
    final dek = await _quick.readDek(vid);
    if (dek == null) {
      throw StateError(
        'Primero configura el desbloqueo rápido desde la app (Ajustes)',
      );
    }
    _dek = dek.toList();
    final payload = await _repo.loadPayload(_dek!);
    _pages = List.from(payload.pages);
    _loadRevisionsFromPayload(payload);
    _pickInitialSelection();
    _state = VaultFlowState.unlocked;
    notifyListeners();
  }

  Future<void> unlockWithPasskey() async {
    await _rp.loadFromDisk();
    final jsonRequest = _rp.startPasskeyLogin();
    final request = AuthenticateRequestType.fromJsonString(jsonRequest);
    final response = await _passkeys.authenticate(request);
    await _rp.finishPasskeyLogin(response: response.toJsonString());
    final vid = _vaultId;
    if (vid == null) {
      throw StateError('No hay cofre activo');
    }
    final dek = await _quick.readDek(vid);
    if (dek == null) {
      throw StateError(
        'No hay clave de desbloqueo rápido. Entra con contraseña y vuelve a registrar la passkey.',
      );
    }
    _dek = dek.toList();
    final payload = await _repo.loadPayload(_dek!);
    _pages = List.from(payload.pages);
    _loadRevisionsFromPayload(payload);
    _pickInitialSelection();
    _state = VaultFlowState.unlocked;
    notifyListeners();
  }

  void lock() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _revisionIdleTimer?.cancel();
    _revisionIdleTimer = null;
    _pageIdsPendingRevision.clear();
    _dek = null;
    _pages = [];
    _pageRevisions.clear();
    _contentEpoch = 0;
    _selectedPageId = null;
    _state = VaultFlowState.locked;
    notifyListeners();
  }

  Future<void> enableDeviceQuickUnlock() async {
    if (_dek == null) return;
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) {
      throw StateError('No disponible en este dispositivo');
    }
    final ok = await _localAuth.authenticate(
      localizedReason:
          'Confirma para guardar el desbloqueo con Hello / biometría',
    );
    if (!ok) return;
    final vid = _vaultId;
    if (vid == null) return;
    await _quick.enableWithDek(vid, Uint8List.fromList(_dek!));
    notifyListeners();
  }

  Future<void> registerPasskey() async {
    if (_dek == null) return;
    await _rp.loadFromDisk();
    final jsonRequest = _rp.startPasskeyRegister();
    final request = RegisterRequestType.fromJsonString(jsonRequest);
    final response = await _passkeys.register(request);
    await _rp.finishPasskeyRegister(response: response.toJsonString());
    final vid = _vaultId;
    if (vid == null) return;
    await _quick.enableWithDek(vid, Uint8List.fromList(_dek!));
    notifyListeners();
  }

  Future<void> disableQuickUnlock() async {
    final vid = _vaultId;
    if (vid == null) return;
    await _quick.disable(vid);
    notifyListeners();
  }

  Future<void> revokePasskey() async {
    await _rp.clearPasskey();
    notifyListeners();
  }

  void selectPage(String id) {
    if (_pages.every((p) => p.id != id)) return;
    _selectedPageId = id;
    notifyListeners();
  }

  void addPage({String? parentId}) {
    final id = _uuid.v4();
    _pages.add(
      FolioPage(
        id: id,
        title: 'Nueva página',
        parentId: parentId,
        blocks: [FolioBlock(id: '${id}_b0', type: 'paragraph', text: '')],
      ),
    );
    _selectedPageId = id;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  bool _hasChildren(String id) => _pages.any((p) => p.parentId == id);

  void deletePage(String id) {
    if (_pages.length <= 1) return;
    if (_hasChildren(id)) return;
    final idx = _pages.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final doomed = _pages[idx];
    for (final b in doomed.blocks) {
      if (b.type == 'image' && b.text.isNotEmpty) {
        _deleteManagedAttachmentIfUnused(
          b.text,
          excludingPageId: doomed.id,
          excludingBlockId: b.id,
        );
      }
      if ((b.type == 'file' || b.type == 'video') &&
          _isManagedAttachmentPath(b.url)) {
        _deleteManagedAttachmentIfUnused(
          b.url!,
          excludingPageId: doomed.id,
          excludingBlockId: b.id,
        );
      }
    }
    final wasSelected = _selectedPageId == id;
    _pages.removeAt(idx);
    _pageRevisions.remove(id);
    _pageIdsPendingRevision.remove(id);
    if (wasSelected) {
      _pickInitialSelection();
    }
    notifyListeners();
    scheduleSave();
  }

  void renamePage(String id, String title) {
    final p = _pageById(id);
    if (p == null) return;
    final t = title.trim();
    if (t.isEmpty) return;
    p.title = t;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: id);
  }

  void setPageParent(String pageId, String? newParentId) {
    if (pageId == newParentId) return;
    if (newParentId != null) {
      if (!_pages.any((p) => p.id == newParentId)) return;
      if (_isDescendant(ancestorId: pageId, nodeId: newParentId)) return;
    }
    final p = _pages.firstWhere((e) => e.id == pageId);
    p.parentId = newParentId;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Verdadero si [nodeId] está bajo [ancestorId] en el árbol.
  bool isUnderAncestor({required String ancestorId, required String nodeId}) {
    return _isDescendant(ancestorId: ancestorId, nodeId: nodeId);
  }

  bool _isDescendant({required String ancestorId, required String nodeId}) {
    var cur = _pageById(nodeId);
    while (cur != null) {
      if (cur.parentId == ancestorId) return true;
      if (cur.parentId == null) return false;
      cur = _pageById(cur.parentId!);
    }
    return false;
  }

  void updateBlockText(String pageId, String blockId, String text) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    if (b.type == 'image' && b.text.isNotEmpty && b.text != text) {
      _deleteManagedAttachmentIfUnused(
        b.text,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
    }
    b.text = text;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void setBlockChecked(String pageId, String blockId, bool checked) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'todo') return;
    b.checked = checked;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void updateBlockIcon(String pageId, String blockId, String? icon) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    b.icon = icon;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void updateBlockUrl(String pageId, String blockId, String? url) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    final old = b.url;
    if (_isManagedAttachmentPath(old) && old != url) {
      _deleteManagedAttachmentIfUnused(
        old!,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
    }
    b.url = url;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void changeBlockType(String pageId, String blockId, String newType) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    final oldType = b.type;
    if (oldType == 'image' && newType != 'image' && b.text.isNotEmpty) {
      _deleteManagedAttachmentIfUnused(
        b.text,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
    }
    if ((oldType == 'file' || oldType == 'video') &&
        newType != oldType &&
        _isManagedAttachmentPath(b.url)) {
      _deleteManagedAttachmentIfUnused(
        b.url!,
        excludingPageId: pageId,
        excludingBlockId: blockId,
      );
      b.url = null;
    }
    if (oldType == 'image' && newType != 'image') {
      b.text = '';
    } else if (oldType == 'table' && newType != 'table') {
      b.text = '';
    }
    b.type = newType;
    if (newType != 'todo') {
      b.checked = null;
    } else {
      b.checked = b.checked ?? false;
    }
    if (newType == 'table') {
      if (b.text.isEmpty || FolioTableData.tryParse(b.text) == null) {
        b.text = FolioTableData.empty().encode();
      }
    } else if (newType == 'image' && oldType != 'image') {
      b.text = '';
    }
    if (newType == 'code' && oldType != 'code') {
      b.codeLanguage ??= 'dart';
    }
    if (newType != 'code') {
      b.codeLanguage = null;
    }
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void setBlockCodeLanguage(String pageId, String blockId, String languageId) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'code') return;
    b.codeLanguage = languageId;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void insertBlockAfter({
    required String pageId,
    required String afterBlockId,
    required FolioBlock block,
  }) {
    final page = _pageById(pageId);
    if (page == null) return;
    final i = page.blocks.indexWhere((b) => b.id == afterBlockId);
    if (i < 0) return;
    page.blocks.insert(i + 1, block);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Divide un bloque en dos en el cursor: [before] queda en el actual, [after] en uno nuevo debajo.
  void splitBlockAtCaret({
    required String pageId,
    required String blockId,
    required String before,
    required String after,
  }) {
    final page = _pageById(pageId);
    if (page == null) return;
    final i = page.blocks.indexWhere((b) => b.id == blockId);
    if (i < 0) return;
    final cur = page.blocks[i];
    cur.text = before;
    final sameListType = cur.type == 'bullet' || cur.type == 'todo';
    final sameCode = cur.type == 'code';
    final nextType = sameListType
        ? cur.type
        : (sameCode ? 'code' : 'paragraph');
    final newBlock = FolioBlock(
      id: '${pageId}_${_uuid.v4()}',
      type: nextType,
      text: after,
      checked: nextType == 'todo' ? false : null,
      codeLanguage: nextType == 'code' ? cur.codeLanguage : null,
    );
    page.blocks.insert(i + 1, newBlock);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Inserta un párrafo vacío justo después del bloque indicado.
  void insertEmptyParagraphAfter({
    required String pageId,
    required String afterBlockId,
  }) {
    insertBlockAfter(
      pageId: pageId,
      afterBlockId: afterBlockId,
      block: FolioBlock(
        id: '${pageId}_${_uuid.v4()}',
        type: 'paragraph',
        text: '',
      ),
    );
  }

  /// Fusiona el contenido del bloque actual con el anterior y elimina el actual.
  /// Devuelve `false` si la fusión no aplica (p. ej. tabla o imagen).
  bool mergeBlockUp(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null) return false;
    final i = page.blocks.indexWhere((b) => b.id == blockId);
    if (i <= 0) return false;
    final prev = page.blocks[i - 1];
    final cur = page.blocks[i];
    if (!folioBlocksCanMerge(prev, cur)) {
      return false;
    }
    prev.text = prev.text + cur.text;
    page.blocks.removeAt(i);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
    return true;
  }

  /// Mueve el bloque [delta] posiciones (-1 arriba, +1 abajo).
  void moveBlock(String pageId, String blockId, int delta) {
    final page = _pageById(pageId);
    if (page == null) return;
    final i = page.blocks.indexWhere((b) => b.id == blockId);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= page.blocks.length) return;
    final b = page.blocks.removeAt(i);
    page.blocks.insert(j, b);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Aumenta la indentación del bloque actual.
  void indentBlock(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    if (b.depth < 3) {
      b.depth += 1;
      notifyListeners();
      scheduleSave(trackRevisionForPageId: pageId);
    }
  }

  /// Reduce la indentación del bloque actual.
  void unindentBlock(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    if (b.depth > 0) {
      b.depth -= 1;
      notifyListeners();
      scheduleSave(trackRevisionForPageId: pageId);
    }
  }

  /// Reordena por arrastre. [newIndex] es el índice destino según [ReorderableListView].
  void reorderBlockAt(String pageId, int oldIndex, int newIndex) {
    final page = _pageById(pageId);
    if (page == null) return;
    final len = page.blocks.length;
    if (oldIndex < 0 || oldIndex >= len) return;
    if (newIndex < 0 || newIndex > len) return;
    var insertAt = newIndex;
    if (insertAt > oldIndex) insertAt -= 1;
    if (insertAt == oldIndex) return;
    final b = page.blocks.removeAt(oldIndex);
    page.blocks.insert(insertAt, b);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  void removeBlockIfMultiple(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null || page.blocks.length <= 1) return;
    FolioBlock? victim;
    for (final b in page.blocks) {
      if (b.id == blockId) {
        victim = b;
        break;
      }
    }
    if (victim != null && victim.type == 'image' && victim.text.isNotEmpty) {
      _deleteManagedAttachmentIfUnused(
        victim.text,
        excludingPageId: pageId,
        excludingBlockId: victim.id,
      );
    }
    if (victim != null &&
        (victim.type == 'file' || victim.type == 'video') &&
        _isManagedAttachmentPath(victim.url)) {
      _deleteManagedAttachmentIfUnused(
        victim.url!,
        excludingPageId: pageId,
        excludingBlockId: victim.id,
      );
    }
    page.blocks.removeWhere((b) => b.id == blockId);
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  /// [trackRevisionForPageId]: tras [_revisionIdleDelay] sin más cambios en esa página,
  /// se añade una entrada al historial (si el contenido difiere de la última revisión).
  void scheduleSave({String? trackRevisionForPageId}) {
    if (_dek == null) return;
    if (trackRevisionForPageId != null) {
      _pageIdsPendingRevision.add(trackRevisionForPageId);
      _revisionIdleTimer?.cancel();
      _revisionIdleTimer = Timer(_revisionIdleDelay, () {
        unawaited(_capturePendingRevisionsAndPersist());
      });
    }
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      _saveDebounce = null;
      notifyListeners();
      unawaited(persistNow());
    });
    notifyListeners();
  }

  Future<void> _capturePendingRevisionsAndPersist() async {
    if (_dek == null) return;
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

  /// Revisiones de una página, más recientes primero.
  List<FolioPageRevision> revisionsForPage(String pageId) {
    final list = _pageRevisions[pageId];
    if (list == null || list.isEmpty) return const [];
    final sorted = List<FolioPageRevision>.from(list)
      ..sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs));
    return sorted;
  }

  /// Quita una entrada del historial sin modificar el contenido actual de la página.
  void deletePageRevision(String pageId, String revisionId) {
    if (_dek == null) return;
    final list = _pageRevisions[pageId];
    if (list == null || list.isEmpty) return;
    final before = list.length;
    list.removeWhere((r) => r.revisionId == revisionId);
    if (list.isEmpty) {
      _pageRevisions.remove(pageId);
    }
    if (list.length == before) return;
    notifyListeners();
    scheduleSave();
  }

  /// Añade una copia de seguridad del estado actual y restaura [revisionId].
  void restorePageRevision(String pageId, String revisionId) {
    if (_dek == null) return;
    final page = _pageById(pageId);
    if (page == null) return;
    final list = _pageRevisions[pageId];
    if (list == null) return;
    final target = list.firstWhereOrNull((r) => r.revisionId == revisionId);
    if (target == null) return;

    final curFp = folioPageContentFingerprint(page);
    final revs = _pageRevisions.putIfAbsent(pageId, () => []);
    if (revs.isEmpty || revs.last.contentFingerprint() != curFp) {
      revs.add(
        FolioPageRevision(
          revisionId: _uuid.v4(),
          savedAtMs: DateTime.now().millisecondsSinceEpoch,
          title: page.title,
          blocksJson: page.blocks.map((b) => b.toJson()).toList(),
        ),
      );
    }

    page.title = target.title;
    page.blocks = target.decodeBlocks();
    _contentEpoch++;
    notifyListeners();
    scheduleSave(trackRevisionForPageId: pageId);
  }

  Future<void> persistNow() async {
    if (_dek == null) return;
    _persistDepth++;
    if (_persistDepth == 1) {
      notifyListeners();
    }
    try {
      await _repo.savePayload(
        VaultPayload(
          version: kVaultPayloadVersion,
          pages: _pages,
          pageRevisions: Map<String, List<FolioPageRevision>>.fromEntries(
            _pageRevisions.entries.map(
              (e) => MapEntry(e.key, List<FolioPageRevision>.from(e.value)),
            ),
          ),
        ),
        _dek!,
      );
    } finally {
      _persistDepth--;
      if (_persistDepth == 0) {
        notifyListeners();
      }
    }
  }

  bool _dekMatchesQuickStorage(Uint8List dek) {
    if (_dek == null) return false;
    return const ListEquality<int>().equals(dek, _dek!);
  }

  /// Comprueba la contraseña contra el cofre y que coincida con la sesión abierta.
  Future<bool> verifyPasswordMatchesUnlockedSession(String password) async {
    if (_dek == null) return false;
    try {
      final dek = await _repo.unlockWithPassword(password);
      return const ListEquality<int>().equals(dek, _dek!);
    } catch (_) {
      return false;
    }
  }

  /// Hello / biometría + DEK almacenada debe coincidir con la sesión.
  Future<void> verifyQuickUnlockMatchesSession() async {
    if (_dek == null) {
      throw StateError('Cofre no desbloqueado');
    }
    final vid = _vaultId;
    if (vid == null) {
      throw StateError('No hay cofre activo');
    }
    final enabled = await _quick.isEnabled(vid);
    if (!enabled) {
      throw StateError('Desbloqueo rápido no configurado');
    }
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) {
      throw StateError('No disponible en este dispositivo');
    }
    final ok = await _localAuth.authenticate(
      localizedReason: 'Confirma tu identidad para borrar el cofre',
    );
    if (!ok) {
      throw StateError('Autenticación cancelada');
    }
    final dek = await _quick.readDek(vid);
    if (dek == null || !_dekMatchesQuickStorage(dek)) {
      throw StateError('No se pudo verificar el desbloqueo rápido');
    }
  }

  /// Passkey + DEK almacenada debe coincidir con la sesión.
  Future<void> verifyPasskeyMatchesSession() async {
    if (_dek == null) {
      throw StateError('Cofre no desbloqueado');
    }
    await _rp.loadFromDisk();
    if (!_rp.hasPasskey) {
      throw StateError('No hay passkey registrada');
    }
    final jsonRequest = _rp.startPasskeyLogin();
    final request = AuthenticateRequestType.fromJsonString(jsonRequest);
    final response = await _passkeys.authenticate(request);
    await _rp.finishPasskeyLogin(response: response.toJsonString());
    final vid = _vaultId;
    if (vid == null) {
      throw StateError('No hay cofre activo');
    }
    final dek = await _quick.readDek(vid);
    if (dek == null || !_dekMatchesQuickStorage(dek)) {
      throw StateError('No coincide la clave tras la passkey');
    }
  }

  /// Borra el cofre **activo** por completo y actualiza el registro.
  Future<void> wipeVaultAndReset() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _revisionIdleTimer?.cancel();
    _revisionIdleTimer = null;
    _pageIdsPendingRevision.clear();

    final id = _vaultId;
    if (id == null) {
      _dek = null;
      _pages = [];
      _pageRevisions.clear();
      _contentEpoch = 0;
      _selectedPageId = null;
      notifyListeners();
      await bootstrap();
      return;
    }

    await _quick.disable(id);
    await VaultPaths.deleteVaultDirectory(id);
    await _registry.remove(id);

    _dek = null;
    _pages = [];
    _pageRevisions.clear();
    _contentEpoch = 0;
    _selectedPageId = null;
    _resumeVaultIdAfterNewVault = null;
    notifyListeners();

    await _registry.load();
    if (_registry.vaults.isEmpty) {
      VaultPaths.clearActiveVaultId();
      await _registry.setActiveVaultId(null);
    } else {
      final next = _registry.vaults.first.id;
      await _registry.setActiveVaultId(next);
      VaultPaths.setActiveVaultId(next);
    }
    await bootstrap();
  }

  void _pickInitialSelection() {
    if (_pages.isEmpty) {
      _selectedPageId = null;
      return;
    }
    final roots = _pages.where((p) => p.parentId == null).toList();
    _selectedPageId = roots.isNotEmpty ? roots.first.id : _pages.first.id;
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _revisionIdleTimer?.cancel();
    super.dispose();
  }
}
