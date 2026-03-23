import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import 'package:uuid/uuid.dart';

import '../data/vault_paths.dart';
import '../data/vault_payload.dart';
import '../data/vault_repository.dart';
import '../models/block.dart';
import '../models/folio_page.dart';
import '../services/folio_rp_server.dart';
import '../services/quick_unlock_storage.dart';

enum VaultFlowState {
  initializing,
  needsOnboarding,
  locked,
  unlocked,
}

class VaultSession extends ChangeNotifier {
  VaultSession({
    VaultRepository? repository,
    QuickUnlockStorage? quickUnlock,
    FolioRpServer? rpServer,
    PasskeyAuthenticator? passkeys,
    LocalAuthentication? localAuth,
  })  : _repo = repository ?? VaultRepository(),
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
  String? _selectedPageId;
  Timer? _saveDebounce;

  VaultFlowState get state => _state;
  List<FolioPage> get pages => List.unmodifiable(_pages);
  String? get selectedPageId => _selectedPageId;

  FolioPage? get selectedPage {
    if (_selectedPageId == null) return null;
    try {
      return _pages.firstWhere((p) => p.id == _selectedPageId);
    } catch (_) {
      return null;
    }
  }

  FolioRpServer get rpServer => _rp;

  Future<bool> get quickUnlockEnabled => _quick.isEnabled();

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
    await _rp.loadFromDisk();
    final exists = await VaultPaths.vaultExists();
    if (!exists) {
      _state = VaultFlowState.needsOnboarding;
      _dek = null;
      _pages = [];
      _selectedPageId = null;
    } else {
      _state = VaultFlowState.locked;
      _dek = null;
    }
    notifyListeners();
  }

  Future<void> completeOnboarding(String password) async {
    _dek = (await _repo.createVault(password: password)).toList();
    final payload = await _repo.loadPayload(_dek!);
    _pages = List.from(payload.pages);
    _pickInitialSelection();
    _state = VaultFlowState.unlocked;
    notifyListeners();
    await persistNow();
  }

  Future<void> unlockWithPassword(String password) async {
    final dek = await _repo.unlockWithPassword(password);
    _dek = dek.toList();
    final payload = await _repo.loadPayload(_dek!);
    _pages = List.from(payload.pages);
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
    final dek = await _quick.readDek();
    if (dek == null) {
      throw StateError('Primero configura el desbloqueo rápido desde la app (Ajustes)');
    }
    _dek = dek.toList();
    final payload = await _repo.loadPayload(_dek!);
    _pages = List.from(payload.pages);
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
    final dek = await _quick.readDek();
    if (dek == null) {
      throw StateError(
        'No hay clave de desbloqueo rápido. Entra con contraseña y vuelve a registrar la passkey.',
      );
    }
    _dek = dek.toList();
    final payload = await _repo.loadPayload(_dek!);
    _pages = List.from(payload.pages);
    _pickInitialSelection();
    _state = VaultFlowState.unlocked;
    notifyListeners();
  }

  void lock() {
    _saveDebounce?.cancel();
    _dek = null;
    _pages = [];
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
      localizedReason: 'Confirma para guardar el desbloqueo con Hello / biometría',
    );
    if (!ok) return;
    await _quick.enableWithDek(Uint8List.fromList(_dek!));
    notifyListeners();
  }

  Future<void> registerPasskey() async {
    if (_dek == null) return;
    await _rp.loadFromDisk();
    final jsonRequest = _rp.startPasskeyRegister();
    final request = RegisterRequestType.fromJsonString(jsonRequest);
    final response = await _passkeys.register(request);
    await _rp.finishPasskeyRegister(response: response.toJsonString());
    await _quick.enableWithDek(Uint8List.fromList(_dek!));
    notifyListeners();
  }

  Future<void> disableQuickUnlock() async {
    await _quick.disable();
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
        blocks: [
          FolioBlock(id: '${id}_b0', type: 'paragraph', text: ''),
        ],
      ),
    );
    _selectedPageId = id;
    notifyListeners();
    scheduleSave();
  }

  bool _hasChildren(String id) => _pages.any((p) => p.parentId == id);

  void deletePage(String id) {
    if (_pages.length <= 1) return;
    if (_hasChildren(id)) return;
    final idx = _pages.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final wasSelected = _selectedPageId == id;
    _pages.removeAt(idx);
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
    scheduleSave();
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
    scheduleSave();
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
    b.text = text;
    scheduleSave();
  }

  void setBlockChecked(String pageId, String blockId, bool checked) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null || b.type != 'todo') return;
    b.checked = checked;
    notifyListeners();
    scheduleSave();
  }

  void changeBlockType(String pageId, String blockId, String newType) {
    final page = _pageById(pageId);
    if (page == null) return;
    final b = _blockById(page, blockId);
    if (b == null) return;
    b.type = newType;
    if (newType != 'todo') {
      b.checked = null;
    } else {
      b.checked = b.checked ?? false;
    }
    notifyListeners();
    scheduleSave();
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
    scheduleSave();
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
    final nextType = sameListType ? cur.type : 'paragraph';
    final newBlock = FolioBlock(
      id: '${pageId}_${_uuid.v4()}',
      type: nextType,
      text: after,
      checked: nextType == 'todo' ? false : null,
    );
    page.blocks.insert(i + 1, newBlock);
    notifyListeners();
    scheduleSave();
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
  void mergeBlockUp(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null) return;
    final i = page.blocks.indexWhere((b) => b.id == blockId);
    if (i <= 0) return;
    final prev = page.blocks[i - 1];
    final cur = page.blocks[i];
    prev.text = prev.text + cur.text;
    page.blocks.removeAt(i);
    notifyListeners();
    scheduleSave();
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
    scheduleSave();
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
    scheduleSave();
  }

  void removeBlockIfMultiple(String pageId, String blockId) {
    final page = _pageById(pageId);
    if (page == null || page.blocks.length <= 1) return;
    page.blocks.removeWhere((b) => b.id == blockId);
    notifyListeners();
    scheduleSave();
  }

  void scheduleSave() {
    if (_dek == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(persistNow());
    });
  }

  Future<void> persistNow() async {
    if (_dek == null) return;
    await _repo.savePayload(VaultPayload(pages: _pages), _dek!);
  }

  void _pickInitialSelection() {
    if (_pages.isEmpty) {
      _selectedPageId = null;
      return;
    }
    final roots = _pages.where((p) => p.parentId == null).toList();
    _selectedPageId =
        roots.isNotEmpty ? roots.first.id : _pages.first.id;
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
}
