import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../crypto/collab_e2e_crypto.dart';
import '../../models/block.dart';
import '../../models/folio_page.dart';
import '../../models/folio_page_revision.dart';
import '../../session/vault_session.dart';
import '../folio_cloud/folio_cloud_callable.dart';
import '../folio_cloud/folio_cloud_entitlements.dart';

bool _collabFirestorePolling() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Mensaje de chat de sala (Firestore).
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

/// Sincroniza una página local con `collabRooms/{roomId}` y mensajes en subcolección.
///
/// Contenido y chat E2E cuando la sala tiene `e2eV == 1`; salas antiguas siguen en claro.
class CollabSessionController extends ChangeNotifier {
  CollabSessionController({
    required this.vaultSession,
    required this.folioCloudEntitlements,
  });

  final VaultSession vaultSession;
  final FolioCloudEntitlementsController folioCloudEntitlements;

  String? _pageId;
  String? _roomId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _msgSub;
  Timer? _pollTimer;
  Timer? _pushDebounce;
  VoidCallback? _vaultListener;

  int _lastAppliedRemoteVersion = 0;
  int _lastLocalPushMs = 0;
  final List<CollabChatMessageView> _messages = [];

  SecretKey? _roomKey;

  /// `null` = aún no leído; true/false según último snapshot de sala.
  bool? _roomUsesE2e;

  List<CollabChatMessageView> get messages => List.unmodifiable(_messages);
  String? get activeRoomId => _roomId;
  String? get activePageId => _pageId;
  bool get isAttached => _roomId != null && _pageId != null;

  int? _remoteContentVersion;
  int? get remoteContentVersion => _remoteContentVersion;

  /// Código para compartir o descifrar (local / pegado al unirse). No viene de Firestore en salas nuevas.
  String? _roomJoinCode;
  String? get roomJoinCode => _roomJoinCode;

  String? _lastError;
  String? get lastError => _lastError;

  bool _isValidRoomId(String? raw) {
    final rid = raw?.trim();
    if (rid == null || rid.isEmpty) return false;
    // Evita aceptar placeholders visuales (--- / —) como roomId real.
    if (RegExp(r'^[-—]+$').hasMatch(rid)) return false;
    return true;
  }

  void _setErrorCode(String code) {
    _lastError = code;
    notifyListeners();
  }

  bool _isCollabPermissionDeniedError(Object e) {
    if (e is FirebaseException) {
      final code = e.code.toLowerCase();
      if (code == 'permission-denied' ||
          code == 'cloud_firestore/permission-denied') {
        return true;
      }
    }
    final m = '$e'.toLowerCase();
    return m.contains('permission-denied') ||
        m.contains('insufficient permissions');
  }

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
    if (hint != null && hint.isNotEmpty) {
      return hint;
    }
    final page = vaultSession.pages.firstWhereOrNull((p) => p.id == _pageId);
    final c = page?.collabJoinCode?.trim();
    if (c != null && c.isNotEmpty) {
      return c;
    }
    return null;
  }

  /// Tras guardar el código en la libreta, reintenta descifrar y refresca sala + mensajes.
  Future<void> applyJoinCodeAndResync(String rawCode) async {
    final t = rawCode.trim();
    if (t.isEmpty || _pageId == null) return;
    vaultSession.setPageCollabJoinCode(_pageId!, t);
    _roomJoinCode = CollabE2eCrypto.normalizeJoinCode(t);
    _roomKey = null;
    notifyListeners();
    try {
      if (_collabFirestorePolling()) {
        await _pollRoomAndMessages();
      } else {
        final roomRef = FirebaseFirestore.instance
            .collection('collabRooms')
            .doc(_roomId);
        final snap = await roomRef.get();
        await _handleRoomSnapshot(snap);
        final msgSnap = await roomRef
            .collection('messages')
            .orderBy('createdAt')
            .limit(400)
            .get();
        await _handleMessagesQuery(msgSnap.docs);
      }
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
    if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) {
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
    _lastAppliedRemoteVersion = 0;
    _messages.clear();
    _roomJoinCode = resolvedCode;
    _vaultListener = _onVaultChanged;
    vaultSession.addListener(_vaultListener!);
    _startFirestore();
    notifyListeners();
  }

  Future<void> _refetchAfterJoinCode() async {
    if (!isAttached) return;
    try {
      if (_collabFirestorePolling()) {
        await _pollRoomAndMessages();
      } else {
        final roomRef = FirebaseFirestore.instance
            .collection('collabRooms')
            .doc(_roomId);
        final snap = await roomRef.get();
        await _handleRoomSnapshot(snap);
      }
    } catch (e) {
      _handleCollabError(e);
    }
  }

  void detach() {
    _pushDebounce?.cancel();
    _pushDebounce = null;
    unawaited(_roomSub?.cancel());
    unawaited(_msgSub?.cancel());
    _roomSub = null;
    _msgSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_vaultListener != null) {
      vaultSession.removeListener(_vaultListener!);
      _vaultListener = null;
    }
    _pageId = null;
    _roomId = null;
    _lastAppliedRemoteVersion = 0;
    _messages.clear();
    _remoteContentVersion = null;
    _roomJoinCode = null;
    _roomKey = null;
    _roomUsesE2e = null;
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  void _onVaultChanged() {
    if (!isAttached) return;
    if (vaultSession.selectedPageId != _pageId) return;
    _schedulePush();
  }

  void _schedulePush() {
    if (!isAttached) return;
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 480), () {
      unawaited(_flushPush());
    });
  }

  Future<SecretKey?> _unwrapRoomKey(Map<String, dynamic> d) async {
    final w = d['wrappedRoomKey'] as String?;
    if (w == null || w.isEmpty) {
      return null;
    }
    final code = _effectiveJoinCode();
    if (code == null) {
      return null;
    }
    final norm = CollabE2eCrypto.normalizeJoinCode(code);
    try {
      return await CollabE2eCrypto.unwrapRoomKeyB64(
        wrappedB64: w,
        joinCodeNormalized: norm,
        roomId: _roomId!,
      );
    } on CollabE2eException catch (e) {
      _lastError = e.message;
      return null;
    } catch (e) {
      _lastError = '$e';
      return null;
    }
  }

  Future<void> _sealPendingE2eRoom(Map<String, dynamic> data) async {
    if (_roomId == null || _pageId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.uid != data['ownerUid']) return;
    final code = _effectiveJoinCode();
    if (code == null) {
      _lastError = 'collab_needs_join_code';
      notifyListeners();
      return;
    }
    final page = vaultSession.pages.firstWhereOrNull((p) => p.id == _pageId);
    if (page == null) return;

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
    final roomRef = FirebaseFirestore.instance
        .collection('collabRooms')
        .doc(_roomId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(roomRef);
        final d = snap.data() ?? {};
        if ((d['contentVersion'] as num?)?.toInt() != 0) {
          return;
        }
        final members = (d['memberUids'] as List<dynamic>?) ?? [];
        if (!members.map((e) => '$e').contains(user.uid)) {
          throw StateError('not_member');
        }
        tx.update(roomRef, {
          'wrappedRoomKey': wrapped,
          'contentCipher': cipher,
          'contentVersion': 1,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        });
      });
      _roomKey = roomKey;
      _lastAppliedRemoteVersion = 1;
      _remoteContentVersion = 1;
    } catch (e) {
      _lastError = '$e';
    }
    notifyListeners();
  }

  Future<void> _flushPush() async {
    if (!isAttached) return;
    if (Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final page = vaultSession.pages.firstWhereOrNull((p) => p.id == _pageId);
    if (page == null) return;
    final roomRef = FirebaseFirestore.instance
        .collection('collabRooms')
        .doc(_roomId);
    try {
      var newVersion = 0;
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(roomRef);
        if (!snap.exists) {
          throw StateError('room_missing');
        }
        final d = snap.data() ?? {};
        final members = (d['memberUids'] as List<dynamic>?) ?? [];
        if (!members.map((e) => '$e').contains(user.uid)) {
          throw StateError('not_member');
        }
        final e2eV = (d['e2eV'] as num?)?.toInt() ?? 0;
        final usesE2e = e2eV == 1;
        final v = (d['contentVersion'] as num?)?.toInt() ?? 0;
        if (!usesE2e) {
          throw StateError('e2e_required');
        }
        if (usesE2e && v == 0) {
          throw StateError('pending_seal');
        }
        newVersion = v + 1;
        var key = _roomKey;
        key ??= await _unwrapRoomKey(d);
        if (key == null) {
          throw StateError('no_room_key');
        }
        _roomKey = key;
        final blocksJson = page.blocks.map((b) => b.toJson()).toList();
        final cipher = await CollabE2eCrypto.encryptPagePayloadB64(
          title: page.title,
          blocksJson: blocksJson,
          roomKey: key,
        );
        tx.update(roomRef, {
          'contentCipher': cipher,
          'contentVersion': newVersion,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        });
      });
      _lastLocalPushMs = DateTime.now().millisecondsSinceEpoch;
      _lastAppliedRemoteVersion = newVersion;
    } on StateError catch (e) {
      if (e.message == 'pending_seal') {
        return;
      }
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

  void _startFirestore() {
    if (!isAttached) return;
    final roomRef = FirebaseFirestore.instance
        .collection('collabRooms')
        .doc(_roomId);
    final msgQuery = roomRef
        .collection('messages')
        .orderBy('createdAt')
        .limit(400);

    if (_collabFirestorePolling()) {
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        unawaited(_pollRoomAndMessages());
      });
      unawaited(_pollRoomAndMessages());
      return;
    }

    _roomSub = roomRef.snapshots().listen(
      (snap) => unawaited(_handleRoomSnapshot(snap)),
      onError: (Object e, StackTrace st) {
        _lastError = '$e';
        notifyListeners();
      },
    );
    _msgSub = msgQuery.snapshots().listen(
      (snap) => unawaited(_handleMessagesSnapshot(snap)),
      onError: (Object e, StackTrace st) {
        _lastError = '$e';
        notifyListeners();
      },
    );
  }

  Future<void> _pollRoomAndMessages() async {
    if (!isAttached) return;
    try {
      final roomRef = FirebaseFirestore.instance
          .collection('collabRooms')
          .doc(_roomId);
      final roomSnap = await roomRef.get();
      if (roomSnap.exists) {
        await _handleRoomSnapshot(roomSnap);
      }
      final msgSnap = await roomRef
          .collection('messages')
          .orderBy('createdAt')
          .limit(400)
          .get();
      await _handleMessagesQuery(msgSnap.docs);
    } catch (e) {
      _handleCollabError(e);
    }
  }

  Future<void> _handleRoomSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    if (!isAttached || !snap.exists) return;
    final data = snap.data();
    if (data == null) return;

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

  Future<void> _handleMessagesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    try {
      await _handleMessagesQuery(snap.docs);
    } catch (e) {
      _handleCollabError(e);
    }
  }

  Future<void> _handleMessagesQuery(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final list = <CollabChatMessageView>[];
    SecretKey? key = _roomKey;
    if (_roomUsesE2e == true) {
      final roomRef = FirebaseFirestore.instance
          .collection('collabRooms')
          .doc(_roomId);
      final rs = await roomRef.get();
      final d = rs.data();
      if (d != null) {
        key ??= await _unwrapRoomKey(d);
        if (key != null) {
          _roomKey = key;
        }
      }
    }
    for (final d in docs) {
      final m = d.data();
      final ts = m['createdAt'];
      int ms = 0;
      if (ts is Timestamp) {
        ms = ts.millisecondsSinceEpoch;
      }
      final e2eMsg =
          (m['e2eV'] as num?)?.toInt() == 1 ||
          (m['cipherText'] as String?)?.isNotEmpty == true;
      if (e2eMsg && key != null) {
        final ct = m['cipherText'] as String? ?? '';
        try {
          final dec = await CollabE2eCrypto.decryptChatMessageB64(
            cipherB64: ct,
            roomKey: key,
          );
          list.add(
            CollabChatMessageView(
              id: d.id,
              authorUid: '${m['authorUid'] ?? ''}',
              authorName: dec.authorName,
              text: dec.text,
              createdAtMs: ms,
            ),
          );
        } on CollabE2eException {
          list.add(
            CollabChatMessageView(
              id: d.id,
              authorUid: '${m['authorUid'] ?? ''}',
              authorName: '',
              text: '…',
              createdAtMs: ms,
            ),
          );
        }
      } else if (e2eMsg && key == null) {
        list.add(
          CollabChatMessageView(
            id: d.id,
            authorUid: '${m['authorUid'] ?? ''}',
            authorName: '${m['authorName'] ?? ''}',
            text: '…',
            createdAtMs: ms,
          ),
        );
      } else {
        list.add(
          CollabChatMessageView(
            id: d.id,
            authorUid: '${m['authorUid'] ?? ''}',
            authorName: '${m['authorName'] ?? ''}',
            text: '${m['text'] ?? ''}',
            createdAtMs: ms,
          ),
        );
      }
    }
    _messages
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  Future<void> sendChatMessage(String text) async {
    final t = text.trim();
    if (t.isEmpty || !isAttached) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email?.trim().isNotEmpty == true
              ? user.email!.trim()
              : user.uid);
    final localNow = DateTime.now().toUtc();
    final optimisticId =
        'local_${localNow.microsecondsSinceEpoch}_${user.uid.substring(0, 6)}';
    _messages.add(
      CollabChatMessageView(
        id: optimisticId,
        authorUid: user.uid,
        authorName: name,
        text: t,
        createdAtMs: localNow.millisecondsSinceEpoch,
      ),
    );
    notifyListeners();

    var sent = false;
    try {
      final roomRef = FirebaseFirestore.instance
          .collection('collabRooms')
          .doc(_roomId);
      var usesE2e = _roomUsesE2e;
      var cv = _remoteContentVersion ?? 1;
      Map<String, dynamic>? roomData;

      if (usesE2e != true || cv <= 0 || _roomKey == null) {
        final rs = await roomRef.get();
        roomData = rs.data() ?? {};
        final e2eV = (roomData['e2eV'] as num?)?.toInt() ?? 0;
        usesE2e = e2eV == 1;
        _roomUsesE2e = usesE2e;
        cv = (roomData['contentVersion'] as num?)?.toInt() ?? 0;
        _remoteContentVersion = cv;
      }

      if (usesE2e != true) {
        _setErrorCode('collab_e2e_required');
        return;
      }
      if (cv == 0) {
        if (roomData != null) {
          await _sealPendingE2eRoom(roomData);
          cv = _remoteContentVersion ?? cv;
        }
        if (cv == 0) {
          final refreshed = await roomRef.get();
          final d2 = refreshed.data() ?? {};
          cv = (d2['contentVersion'] as num?)?.toInt() ?? 0;
          _remoteContentVersion = cv;
          roomData = d2;
        }
        if (cv == 0) {
          _setErrorCode('collab_pending_encryption');
          return;
        }
      }
      final payload = <String, dynamic>{
        'authorUid': user.uid,
        'createdAt': Timestamp.fromDate(DateTime.now().toUtc()),
      };
      var key = _roomKey;
      if (key == null && roomData != null) {
        key = await _unwrapRoomKey(roomData);
      }
      if (key == null) {
        final rs = await roomRef.get();
        key = await _unwrapRoomKey(rs.data() ?? {});
      }
      if (key == null) {
        _setErrorCode('collab_needs_join_code');
        return;
      }
      _roomKey = key;
      final ct = await CollabE2eCrypto.encryptChatMessageB64(
        authorName: name,
        text: t,
        roomKey: key,
      );
      payload['e2eV'] = 1;
      payload['authorName'] = '';
      payload['cipherText'] = ct;
      await roomRef.collection('messages').add(payload);
      sent = true;
    } catch (e) {
      _handleCollabError(e);
    } finally {
      if (!sent) {
        _messages.removeWhere((m) => m.id == optimisticId);
        notifyListeners();
      }
    }
  }

  Future<String?> createRoomForPage({required String pageId}) async {
    if (!folioCloudEntitlements.snapshot.canRealtimeCollab) {
      _lastError = 'no_entitlement';
      notifyListeners();
      return null;
    }
    try {
      final res = await callFolioHttpsCallable('createCollabRoom', {
        'vaultPageId': pageId,
      });
      if (res is Map && res['roomId'] is String) {
        final rid = (res['roomId'] as String).trim();
        if (!_isValidRoomId(rid)) {
          _lastError = 'collab_invalid_room_id';
          notifyListeners();
          return null;
        }
        final code = (res['joinCode'] as String?)?.trim();
        if (code == null || code.isEmpty) {
          _lastError = 'collab_no_join_code';
          notifyListeners();
          return null;
        }
        vaultSession.setPageCollabRoomId(pageId, rid, joinCode: code);
        attach(pageId: pageId, roomId: rid, initialJoinCode: code);
        final roomRef = FirebaseFirestore.instance
            .collection('collabRooms')
            .doc(rid);
        final snap = await roomRef.get();
        if (snap.exists) {
          await _sealPendingE2eRoom(snap.data() ?? {});
        }
        return rid;
      }
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
    }
    return null;
  }

  Future<void> inviteMember(String targetUid) async {
    if (_roomId == null) return;
    try {
      await callFolioHttpsCallable('inviteCollabMember', {
        'roomId': _roomId,
        'targetUid': targetUid.trim(),
      });
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
    }
  }

  Future<void> leaveRoom({required String pageId}) async {
    if (_roomId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    var ok = false;
    try {
      final roomRef = FirebaseFirestore.instance
          .collection('collabRooms')
          .doc(_roomId);
      final snap = await roomRef.get();
      final data = snap.data() ?? <String, dynamic>{};
      final ownerUid = (data['ownerUid'] as String?)?.trim();
      final amOwner = ownerUid != null && ownerUid == user.uid;
      if (amOwner) {
        await callFolioHttpsCallable('closeCollabRoom', {'roomId': _roomId});
      } else {
        await callFolioHttpsCallable('removeCollabMember', {
          'roomId': _roomId,
          'targetUid': user.uid,
        });
      }
      ok = true;
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
    }
    if (!ok) return;
    vaultSession.setPageCollabRoomId(pageId, null);
    detach();
  }

  Future<void> archiveChatToVault(String pageId) async {
    if (_messages.isEmpty) return;
    vaultSession.archiveCollabChatToComments(
      pageId: pageId,
      messages: _messages
          .map(
            (m) => (
              messageId: m.id,
              authorUid: m.authorUid,
              authorName: m.authorName,
              text: m.text,
              createdAtMs: m.createdAtMs,
            ),
          )
          .toList(),
    );
  }

  Future<bool> joinRoomByCode({
    required String pageId,
    required String joinCodeInput,
  }) async {
    if (Firebase.apps.isEmpty) return false;
    if (FirebaseAuth.instance.currentUser == null) return false;
    try {
      final res = await callFolioHttpsCallable('joinCollabRoomByCode', {
        'joinCode': joinCodeInput,
      });
      if (res is Map && res['roomId'] is String) {
        final rid = (res['roomId'] as String).trim();
        if (!_isValidRoomId(rid)) {
          _lastError = 'collab_invalid_room_id';
          notifyListeners();
          return false;
        }
        final code = joinCodeInput.trim();
        vaultSession.setPageCollabRoomId(pageId, rid, joinCode: code);
        attach(pageId: pageId, roomId: rid, initialJoinCode: code);
        return true;
      }
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
    }
    return false;
  }
}
