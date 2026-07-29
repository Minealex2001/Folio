import 'dart:async';

import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../crypto/collab_e2e_crypto.dart';
import '../../models/block.dart';
import '../../models/folio_page.dart';
import '../../models/folio_page_revision.dart';
import '../../session/vault_session.dart';
import '../app_logger.dart';
import '../folio_cloud/folio_cloud_callable.dart';
import '../folio_cloud/folio_cloud_entitlements.dart';
import '../folio_cloud/folio_cloud_exception.dart';
import '../folio_cloud/folio_cloud_identity.dart';
import 'collab_spring_api.dart';
import 'collab_stomp_transport.dart';

/// Mensaje de chat de sala (UI). En Spring el chat aún no está portado.
@immutable
class CollabChatMessageView {
  const CollabChatMessageView({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAtMs,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final int createdAtMs;
}

/// Sincroniza una página local con la sala collab vía Spring STOMP + REST.
///
/// Contenido E2E cuando la sala tiene `e2eV == 1`. Chat de sala no disponible.
class CollabSessionController extends ChangeNotifier {
  CollabSessionController({
    required this.vaultSession,
    required this.folioCloudEntitlements,
    CollabSpringApi? springApi,
    CollabStompTransport? stompTransport,
  }) : _springApi = springApi ?? CollabSpringApi(),
       _stomp = stompTransport ?? CollabStompTransport();

  final VaultSession vaultSession;
  final FolioCloudEntitlementsController folioCloudEntitlements;
  final CollabSpringApi _springApi;
  final CollabStompTransport _stomp;

  String? _pageId;
  String? _roomId;
  Timer? _pushDebounce;
  VoidCallback? _vaultListener;

  int _lastAppliedRemoteVersion = 0;
  int _lastLocalPushMs = 0;
  final List<CollabChatMessageView> _messages = [];

  SecretKey? _roomKey;
  bool? _roomUsesE2e;
  Map<String, dynamic>? _springRoomCache;

  List<CollabChatMessageView> get messages => List.unmodifiable(_messages);
  String? get activeRoomId => _roomId;
  String? get activePageId => _pageId;
  bool get isAttached => _roomId != null && _pageId != null;

  int? _remoteContentVersion;
  int? get remoteContentVersion => _remoteContentVersion;

  String? _roomJoinCode;
  String? get roomJoinCode => _roomJoinCode;

  String? _lastError;
  String? get lastError => _lastError;

  bool _isValidRoomId(String? raw) {
    final rid = raw?.trim();
    if (rid == null || rid.isEmpty) return false;
    if (RegExp(r'^[-—]+$').hasMatch(rid)) return false;
    return true;
  }

  void _setErrorCode(String code) {
    _lastError = code;
    notifyListeners();
  }

  bool _isCollabPermissionDeniedError(Object e) {
    if (e is CollabSpringApiException) {
      return e.code == 'permission_denied' || e.code == 'not_found';
    }
    if (e is FolioCloudException) {
      final code = e.code.toLowerCase();
      if (code == 'permission-denied' || code == 'not-found') return true;
    }
    final m = '$e'.toLowerCase();
    return m.contains('permission-denied') ||
        m.contains('insufficient permissions') ||
        m.contains('not a member of this collab room');
  }

  String? _currentUid() => folioCloudCurrentUid();

  void _handleRoomClosedByPermissionDenied() {
    final pageId = _pageId;
    _lastError = 'collab_room_closed';
    if (pageId != null) {
      vaultSession.setPageCollabRoomId(pageId, null);
    }
    detach();
  }

  void _handleCollabError(Object e) {
    if (_isCollabPermissionDeniedError(e)) {
      _handleRoomClosedByPermissionDenied();
      return;
    }
    _lastError = '$e';
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  String? _effectiveJoinCode() {
    final hint = _roomJoinCode?.trim();
    if (hint != null && hint.isNotEmpty) return hint;
    final page = vaultSession.pages.firstWhereOrNull((p) => p.id == _pageId);
    final c = page?.collabJoinCode?.trim();
    if (c != null && c.isNotEmpty) return c;
    return null;
  }

  Future<void> applyJoinCodeAndResync(String rawCode) async {
    final t = rawCode.trim();
    if (t.isEmpty || _pageId == null) return;
    vaultSession.setPageCollabJoinCode(_pageId!, t);
    _roomJoinCode = CollabE2eCrypto.normalizeJoinCode(t);
    _roomKey = null;
    notifyListeners();
    try {
      await _fetchSpringRoomAndApply();
    } catch (e) {
      _handleCollabError(e);
    }
  }

  void attach({
    required String pageId,
    required String roomId,
    String? initialJoinCode,
  }) {
    final rid = roomId.trim();
    if (!_isValidRoomId(rid)) {
      detach();
      return;
    }
    if (!folioCloudHasSession()) {
      detach();
      return;
    }
    final page = vaultSession.pages.firstWhereOrNull((p) => p.id == pageId);
    final fromPage = page?.collabJoinCode?.trim();
    final hint = initialJoinCode?.trim();
    final resolvedCode = (hint != null && hint.isNotEmpty)
        ? CollabE2eCrypto.normalizeJoinCode(hint)
        : (fromPage != null && fromPage.isNotEmpty
              ? CollabE2eCrypto.normalizeJoinCode(fromPage)
              : null);

    if (_pageId == pageId && _roomId == rid) {
      if (resolvedCode != null) {
        _roomJoinCode = resolvedCode;
        _roomKey = null;
        notifyListeners();
        unawaited(_refetchAfterJoinCode());
      }
      return;
    }

    detach();
    _pageId = pageId;
    _roomId = rid;
    _roomJoinCode = resolvedCode;
    _lastAppliedRemoteVersion = 0;
    _remoteContentVersion = null;
    _roomKey = null;
    _roomUsesE2e = null;
    _springRoomCache = null;
    _messages.clear();
    _lastError = null;

    _vaultListener = _onVaultChanged;
    vaultSession.addListener(_vaultListener!);

    unawaited(_connectSpring());
    notifyListeners();
  }

  Future<void> _refetchAfterJoinCode() async {
    try {
      await _fetchSpringRoomAndApply();
    } catch (e) {
      _handleCollabError(e);
    }
  }

  Future<void> _connectSpring() async {
    if (!isAttached || _roomId == null) return;
    try {
      await _fetchSpringRoomAndApply();
      await _stomp.connect(
        roomId: _roomId!,
        onRoomUpdate: (json) => unawaited(_handleSpringTopicPayload(json)),
        onError: (json) {
          final msg = json['message']?.toString() ?? json['error']?.toString();
          if (msg != null && msg.isNotEmpty) {
            _lastError = msg;
            notifyListeners();
          }
        },
      );
    } catch (e) {
      _handleCollabError(e);
    }
  }

  void detach() {
    _pushDebounce?.cancel();
    _pushDebounce = null;
    final vl = _vaultListener;
    _vaultListener = null;
    if (vl != null) {
      vaultSession.removeListener(vl);
    }
    unawaited(_stomp.disconnect());
    _pageId = null;
    _roomId = null;
    _roomJoinCode = null;
    _roomKey = null;
    _roomUsesE2e = null;
    _springRoomCache = null;
    _remoteContentVersion = null;
    _lastAppliedRemoteVersion = 0;
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  void _onVaultChanged() {
    if (!isAttached) return;
    _schedulePush();
  }

  void _schedulePush() {
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_flushPush());
    });
  }

  Future<SecretKey?> _unwrapRoomKey(Map<String, dynamic> data) async {
    final code = _effectiveJoinCode();
    if (code == null) {
      _setErrorCode('collab_needs_join_code');
      return null;
    }
    final wrapped = data['wrappedRoomKey'] as String?;
    if (wrapped == null || wrapped.isEmpty) return null;
    try {
      return await CollabE2eCrypto.unwrapRoomKeyB64(
        wrappedB64: wrapped,
        joinCodeNormalized: CollabE2eCrypto.normalizeJoinCode(code),
        roomId: _roomId!,
      );
    } on CollabE2eException {
      _setErrorCode('collab_needs_join_code');
      return null;
    }
  }

  Future<void> _sealPendingE2eRoom(Map<String, dynamic> data) async {
    if (_roomId == null || _pageId == null) return;
    final uid = _currentUid();
    if (uid == null) return;
    if (uid != data['ownerUid']) return;
    final code = _effectiveJoinCode();
    if (code == null) {
      _lastError = 'collab_needs_join_code';
      notifyListeners();
      return;
    }
    final page = vaultSession.pages.firstWhereOrNull((p) => p.id == _pageId);
    if (page == null) return;

    try {
      final roomKey = await CollabE2eCrypto.generateRoomKey();
      final norm = CollabE2eCrypto.normalizeJoinCode(code);
      final wrapped = await CollabE2eCrypto.wrapRoomKeyB64(
        roomKey: roomKey,
        joinCodeNormalized: norm,
        roomId: _roomId!,
      );
      final blocksJson = page.blocks.map((b) => b.toJson()).toList();
      final cipher = await CollabE2eCrypto.encryptPagePayloadB64(
        title: page.title,
        blocksJson: blocksJson,
        roomKey: roomKey,
      );
      final body = <String, dynamic>{
        'wrappedRoomKey': wrapped,
        'contentCipher': cipher,
        'contentVersion': 1,
        'updatedBy': uid,
        'changedKeys': <String>['wrappedRoomKey', 'contentCipher'],
      };
      try {
        _stomp.sendRoomUpdate(_roomId!, body);
      } catch (_) {
        await _springApi.putRoomUpdate(_roomId!, body);
      }
      _roomKey = roomKey;
      _lastAppliedRemoteVersion = 1;
      _remoteContentVersion = 1;
      _springRoomCache = {
        ...?_springRoomCache,
        ...data,
        ...body,
      };
    } catch (e) {
      _lastError = '$e';
    }
    notifyListeners();
  }

  Future<void> _flushPush() async {
    if (!isAttached) return;
    final uid = _currentUid();
    if (uid == null) return;
    final page = vaultSession.pages.firstWhereOrNull((p) => p.id == _pageId);
    if (page == null) return;

    try {
      var data = _springRoomCache;
      data ??= await _springApi.getRoom(_roomId!);
      _springRoomCache = data;

      final members = (data['memberUids'] as List<dynamic>?) ?? [];
      if (!members.map((e) => '$e').contains(uid) &&
          '${data['ownerUid']}' != uid) {
        throw StateError('not_member');
      }
      final e2eV = (data['e2eV'] as num?)?.toInt() ?? 0;
      final usesE2e = e2eV == 1;
      final v = (data['contentVersion'] as num?)?.toInt() ?? 0;
      if (!usesE2e) throw StateError('e2e_required');
      if (v == 0) throw StateError('pending_seal');

      var key = _roomKey;
      key ??= await _unwrapRoomKey(data);
      if (key == null) throw StateError('no_room_key');
      _roomKey = key;

      final newVersion = v + 1;
      final blocksJson = page.blocks.map((b) => b.toJson()).toList();
      final cipher = await CollabE2eCrypto.encryptPagePayloadB64(
        title: page.title,
        blocksJson: blocksJson,
        roomKey: key,
      );
      final body = <String, dynamic>{
        'contentCipher': cipher,
        'contentVersion': newVersion,
        'updatedBy': uid,
        'changedKeys': <String>['contentCipher'],
      };
      try {
        _stomp.sendRoomUpdate(_roomId!, body);
      } catch (_) {
        await _springApi.putRoomUpdate(_roomId!, body);
      }
      _lastLocalPushMs = DateTime.now().millisecondsSinceEpoch;
      _lastAppliedRemoteVersion = newVersion;
      _remoteContentVersion = newVersion;
      _springRoomCache = {...data, ...body};
    } on StateError catch (e) {
      if (e.message == 'pending_seal') return;
      if (e.message == 'e2e_required') {
        _setErrorCode('collab_e2e_required');
        return;
      }
      if (e.message == 'no_room_key') {
        _setErrorCode('collab_needs_join_code');
        return;
      }
      _lastError = '$e';
      notifyListeners();
    } catch (e) {
      _handleCollabError(e);
    }
  }

  Future<void> _fetchSpringRoomAndApply() async {
    if (!isAttached || _roomId == null) return;
    final data = await _springApi.getRoom(_roomId!);
    _springRoomCache = data;
    await _handleRoomData(data);
  }

  Future<void> _handleSpringTopicPayload(Map<String, dynamic> json) async {
    if (!isAttached) return;
    final type = '${json['type'] ?? ''}';
    if (type.isNotEmpty && type != 'room.update') return;
    final merged = <String, dynamic>{...?_springRoomCache, ...json};
    _springRoomCache = merged;
    await _handleRoomData(merged);
  }

  Future<void> _handleRoomData(Map<String, dynamic> data) async {
    if (!isAttached) return;

    final e2eV = (data['e2eV'] as num?)?.toInt() ?? 0;
    final usesE2e = e2eV == 1;
    _roomUsesE2e = usesE2e;

    if (!usesE2e) {
      _setErrorCode('collab_e2e_required');
      return;
    }

    final v = (data['contentVersion'] as num?)?.toInt() ?? 0;
    _remoteContentVersion = v;

    if (v == 0) {
      await _sealPendingE2eRoom(data);
      return;
    }

    if (v <= _lastAppliedRemoteVersion) {
      notifyListeners();
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastLocalPushMs < 700) {
      notifyListeners();
      return;
    }

    var key = _roomKey;
    key ??= await _unwrapRoomKey(data);
    if (key == null) {
      notifyListeners();
      return;
    }
    _roomKey = key;

    final cipher = data['contentCipher'] as String?;
    if (cipher == null || cipher.isEmpty) {
      _lastAppliedRemoteVersion = v;
      notifyListeners();
      return;
    }
    try {
      final dec = await CollabE2eCrypto.decryptPagePayloadB64(
        cipherB64: cipher,
        roomKey: key,
      );
      final nextBlocks = dec.blocks.map((e) => FolioBlock.fromJson(e)).toList();

      final page = vaultSession.pages.firstWhereOrNull((p) => p.id == _pageId);
      if (page == null) return;

      final remoteFp = folioPageContentFingerprint(
        FolioPage(id: page.id, title: dec.title, blocks: nextBlocks),
      );
      if (folioPageContentFingerprint(page) == remoteFp) {
        _lastAppliedRemoteVersion = v;
        notifyListeners();
        return;
      }

      vaultSession.applyRemoteCollabPageState(
        pageId: _pageId!,
        title: dec.title.isEmpty ? page.title : dec.title,
        blocks: nextBlocks,
      );
      _lastAppliedRemoteVersion = v;
    } on CollabE2eException catch (e) {
      _lastError = e.message;
    } catch (e) {
      _lastError = '$e';
    }
    notifyListeners();
  }

  Future<void> sendChatMessage(String text) async {
    final t = text.trim();
    if (t.isEmpty || !isAttached) return;
    _setErrorCode('collab_chat_spring_unavailable');
  }

  Future<String?> createRoomForPage(String pageId) async {
    if (!folioCloudHasSession()) return null;
    final snap = folioCloudEntitlements.snapshot;
    if (!snap.canUseRealtimeCollab) {
      _setErrorCode('collab_entitlement');
      return null;
    }
    try {
      final res = await callFolioHttpsCallable('createCollabRoom', {
        'pageId': pageId,
      });
      if (res is! Map) return null;
      final roomId = res['roomId']?.toString();
      final joinCode = res['joinCode']?.toString();
      if (roomId == null || roomId.isEmpty) return null;
      if (joinCode != null && joinCode.isNotEmpty) {
        vaultSession.setPageCollabJoinCode(pageId, joinCode);
      }
      vaultSession.setPageCollabRoomId(pageId, roomId);
      attach(pageId: pageId, roomId: roomId, initialJoinCode: joinCode);
      return roomId;
    } catch (e) {
      _handleCollabError(e);
      return null;
    }
  }

  Future<void> inviteMember(String email) async {
    if (_roomId == null) return;
    try {
      await callFolioHttpsCallable('inviteCollabMember', {
        'roomId': _roomId,
        'email': email.trim(),
      });
    } catch (e) {
      _handleCollabError(e);
    }
  }

  Future<void> leaveRoom() async {
    if (_roomId == null || _pageId == null) return;
    final roomId = _roomId!;
    final pageId = _pageId!;
    try {
      final uid = _currentUid();
      final data = _springRoomCache ?? await _springApi.getRoom(roomId);
      final owner = '${data['ownerUid'] ?? ''}';
      if (uid != null && uid == owner) {
        await callFolioHttpsCallable('closeCollabRoom', {'roomId': roomId});
      } else {
        await callFolioHttpsCallable('removeCollabMember', {
          'roomId': roomId,
          'uid': uid,
        });
      }
    } catch (e) {
      _handleCollabError(e);
    } finally {
      vaultSession.setPageCollabRoomId(pageId, null);
      detach();
    }
  }

  Future<void> archiveChatToVault() async {
    // Chat no disponible en Spring.
  }

  Future<bool> joinRoomByCode(String code) async {
    if (!folioCloudHasSession()) return false;
    try {
      final res = await callFolioHttpsCallable('joinCollabRoomByCode', {
        'code': code.trim(),
      });
      if (res is! Map) return false;
      final roomId = res['roomId']?.toString();
      final pageId = res['pageId']?.toString();
      final joinCode = res['joinCode']?.toString() ?? code.trim();
      if (roomId == null || pageId == null) return false;
      vaultSession.setPageCollabRoomId(pageId, roomId);
      vaultSession.setPageCollabJoinCode(pageId, joinCode);
      attach(pageId: pageId, roomId: roomId, initialJoinCode: joinCode);
      return true;
    } catch (e) {
      _handleCollabError(e);
      return false;
    }
  }
}
