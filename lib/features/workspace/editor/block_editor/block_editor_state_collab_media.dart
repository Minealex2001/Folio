part of 'package:folio/features/workspace/editor/block_editor.dart';

/// End-to-end-encrypted collaborative media upload for block editor
/// attachments: room-key resolution, encrypt-and-upload orchestration,
/// local caching of downloaded media, and the upload-progress badge shown
/// under an in-flight block. Split out of `block_editor_state.dart` as a
/// self-contained concern -- it only touches the `_collab*` fields still
/// declared on [BlockEditorState] itself (referenced here via [_mediaSelf]
/// since this mixin cannot declare them without duplicating state used
/// elsewhere in the class, e.g. the collab dispose cleanup).
mixin _CollabMediaUpload on State<BlockEditor> {
  BlockEditorState get _mediaSelf => this as BlockEditorState;

  bool _isValidCollabRoomId(String? raw) {
    final rid = raw?.trim();
    if (rid == null || rid.isEmpty) return false;
    if (RegExp(r'^[-—]+$').hasMatch(rid)) return false;
    return true;
  }

  bool _isCollabMediaUri(String raw) => raw.startsWith('collab-media://');

  ({String roomId, String mediaId})? _parseCollabMediaUri(String raw) {
    final u = Uri.tryParse(raw);
    if (u == null || u.scheme != 'collab-media') return null;
    final roomId = u.host.trim();
    final mediaId = u.pathSegments.isNotEmpty
        ? u.pathSegments.first.trim()
        : '';
    if (!_isValidCollabRoomId(roomId) || mediaId.isEmpty) return null;
    return (roomId: roomId, mediaId: mediaId);
  }

  Future<SecretKey?> _roomKeyForCollabRoom({
    required String roomId,
    required String joinCode,
  }) async {
    final st = _mediaSelf;
    final cached = st._collabRoomKeyCache[roomId];
    if (cached != null) return cached;

    final inFlight = st._collabRoomKeyInFlight[roomId];
    if (inFlight != null) return inFlight;

    final future = (() async {
      final room = await CollabSpringApi().getRoom(roomId);
      final e2eV = (room['e2eV'] as num?)?.toInt() ?? 0;
      if (e2eV != 1) return null;
      final wrapped = (room['wrappedRoomKey'] as String?)?.trim();
      if (wrapped == null || wrapped.isEmpty) return null;
      final key = await CollabE2eCrypto.unwrapRoomKeyB64(
        wrappedB64: wrapped,
        joinCodeNormalized: CollabE2eCrypto.normalizeJoinCode(joinCode),
        roomId: roomId,
      );
      st._collabRoomKeyCache[roomId] = key;
      return key;
    })();

    st._collabRoomKeyInFlight[roomId] = future;
    try {
      return await future;
    } finally {
      st._collabRoomKeyInFlight.remove(roomId);
    }
  }

  bool _shouldEmitCollabUploadUi({
    required String blockId,
    required double? progress,
    required Duration? eta,
  }) {
    final st = _mediaSelf;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = st._collabUploadLastUiMsByBlockId[blockId];
    final nextProgress = progress ?? -1;
    final lastProgress = st._collabUploadLastProgressByBlockId[blockId] ?? -2;
    final nextEtaSec = eta?.inSeconds ?? -1;
    final lastEtaSec = st._collabUploadLastEtaSecByBlockId[blockId] ?? -2;

    final progressChangedEnough =
        progress == null ||
        lastProgress < 0 ||
        (nextProgress - lastProgress).abs() >= 0.02 ||
        nextProgress >= 1.0;
    final etaChanged = nextEtaSec != lastEtaSec;
    final enoughTimeElapsed = lastMs == null || (nowMs - lastMs) >= 180;

    if (!(progressChangedEnough || etaChanged || enoughTimeElapsed)) {
      return false;
    }

    st._collabUploadLastUiMsByBlockId[blockId] = nowMs;
    st._collabUploadLastProgressByBlockId[blockId] = nextProgress;
    st._collabUploadLastEtaSecByBlockId[blockId] = nextEtaSec;
    return true;
  }

  void _enqueueCollabMediaUpload({
    required String pageId,
    required String blockId,
    required File localFile,
    required String mediaKind,
    required void Function(String uri) onCommittedUri,
  }) {
    unawaited(
      _uploadCollabMediaForBlock(
        pageId: pageId,
        blockId: blockId,
        file: localFile,
        mediaKind: mediaKind,
        onCommittedUri: onCommittedUri,
      ),
    );
  }

  /// Bridge público para código fuera del editor (p. ej. el chat de Quill al
  /// insertar una imagen generada) que ya escribió un adjunto local real en
  /// un bloque `image` y necesita disparar la misma subida cifrada que el
  /// picker de imagen dispara automáticamente. Solo funciona si esta página
  /// está montada en este `BlockEditorState` — el llamador es responsable de
  /// comprobarlo (p. ej. vía `GlobalKey<BlockEditorState>.currentState`).
  void notifyExternalImageInserted({
    required String pageId,
    required String blockId,
    required File localFile,
  }) {
    _enqueueCollabMediaUpload(
      pageId: pageId,
      blockId: blockId,
      localFile: localFile,
      mediaKind: 'image',
      onCommittedUri: (uri) => _mediaSelf._s.updateBlockText(pageId, blockId, uri),
    );
  }

  Future<void> _uploadCollabMediaForBlock({
    required String pageId,
    required String blockId,
    required File file,
    required String mediaKind,
    required void Function(String uri) onCommittedUri,
  }) async {
    final st = _mediaSelf;
    final page = st._s.pages.firstWhereOrNull((p) => p.id == pageId);
    final roomId = page?.collabRoomId?.trim();
    final joinCode = page?.collabJoinCode?.trim();
    if (!_isValidCollabRoomId(roomId) || joinCode == null || joinCode.isEmpty) {
      return;
    }
    final fileSize = file.lengthSync();

    final token = _bumpCollabUploadToken(blockId);
    if (mounted) {
      setState(() {
        st._collabUploadByBlockId[blockId] = const _CollabUploadProgress(
          encrypting: true,
        );
      });
    }

    try {
      final prep = await callFolioHttpsCallable('prepareCollabMediaUpload', {
        'roomId': roomId,
        'blockId': blockId,
        'mediaKind': mediaKind,
        'sizeBytes': fileSize,
      });
      if (prep is! Map) return;
      final mediaId = '${prep['mediaId'] ?? ''}'.trim();
      final storagePath = '${prep['storagePath'] ?? ''}'.trim();
      if (mediaId.isEmpty || storagePath.isEmpty) return;

      final roomKey = await _roomKeyForCollabRoom(
        roomId: roomId!,
        joinCode: joinCode,
      );
      if (roomKey == null) return;

      final plain = await file.readAsBytes();
      final cipher = await CollabE2eCrypto.encryptBinaryBytes(
        bytes: Uint8List.fromList(plain),
        roomKey: roomKey,
      );
      final ref = storagePath;
      if (mounted) {
        setState(() {
          st._collabUploadByBlockId[blockId] = const _CollabUploadProgress(
            encrypting: false,
            progress: null,
            eta: null,
          );
        });
      }
      await folioStoragePutData(ref, cipher);

      await callFolioHttpsCallable('commitCollabMediaUpload', {
        'roomId': roomId,
        'mediaId': mediaId,
        'blockId': blockId,
        'storagePath': storagePath,
        'mediaKind': mediaKind,
        'mimeType': '',
        'fileName': p.basename(file.path),
        'sizeBytes': fileSize,
      });
      if (!_isActiveCollabUploadToken(blockId, token)) return;
      final uri = 'collab-media://$roomId/$mediaId';
      onCommittedUri(uri);
      if (mounted) {
        setState(() {
          st._collabUploadByBlockId.remove(blockId);
        });
      }
      st._collabUploadLastUiMsByBlockId.remove(blockId);
      st._collabUploadLastProgressByBlockId.remove(blockId);
      st._collabUploadLastEtaSecByBlockId.remove(blockId);
    } catch (e) {
      if (!_isActiveCollabUploadToken(blockId, token) || !mounted) return;
      setState(() {
        st._collabUploadByBlockId[blockId] = _CollabUploadProgress(
          encrypting: false,
          progress: null,
          eta: null,
          error: '$e',
        );
      });
      st._collabUploadLastUiMsByBlockId.remove(blockId);
      st._collabUploadLastProgressByBlockId.remove(blockId);
      st._collabUploadLastEtaSecByBlockId.remove(blockId);
    }
  }

  Future<File?> _resolveCollabMediaFile(String rawUrl) async {
    // Media collab indexada en Firestore no está portada a Spring aún.
    return null;
  }

  Future<Directory> _collabMediaCacheDir() async {
    final vault = await VaultPaths.vaultDirectory();
    final cacheDir = Directory(
      p.join(vault.path, VaultPaths.attachmentsDirName, '.collab_cache'),
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<File?> _findCachedCollabMediaFile(String mediaId) async {
    final st = _mediaSelf;
    final knownPath = st._collabMediaCachePathByMediaId[mediaId];
    if (knownPath != null) {
      final known = File(knownPath);
      if (await known.exists() && await known.length() > 0) {
        return known;
      }
      st._collabMediaCachePathByMediaId.remove(mediaId);
    }

    final cacheDir = await _collabMediaCacheDir();
    final defaultBin = File(p.join(cacheDir.path, '$mediaId.bin'));
    if (await defaultBin.exists() && await defaultBin.length() > 0) {
      st._collabMediaCachePathByMediaId[mediaId] = defaultBin.path;
      return defaultBin;
    }

    await for (final e in cacheDir.list(followLinks: false)) {
      if (e is! File) continue;
      if (p.basenameWithoutExtension(e.path) != mediaId) continue;
      if (await e.length() <= 0) continue;
      st._collabMediaCachePathByMediaId[mediaId] = e.path;
      return e;
    }
    return null;
  }

  int _bumpCollabUploadToken(String blockId) {
    final st = _mediaSelf;
    final next = (st._collabUploadTokenByBlockId[blockId] ?? 0) + 1;
    st._collabUploadTokenByBlockId[blockId] = next;
    return next;
  }

  bool _isActiveCollabUploadToken(String blockId, int token) {
    return _mediaSelf._collabUploadTokenByBlockId[blockId] == token;
  }

  String _formatEta(Duration? eta) {
    if (eta == null) return '--:--';
    final secs = eta.inSeconds.clamp(0, 359999);
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _buildCollabUploadProgressBadge(
    String blockId,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final st = _mediaSelf;
    final u = st._collabUploadByBlockId[blockId];
    if (u == null) return const SizedBox.shrink();
    if (u.error != null) {
      final l10n = AppLocalizations.of(st.context);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          l10n.collabMediaUploadError('${u.error}'),
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
        ),
      );
    }
    final progress = u.progress;
    final l10n = AppLocalizations.of(st.context);
    final pct = progress == null
        ? l10n.collabMediaPreparingEncryption
        : l10n.collabMediaUploadingProgress(
            (progress * 100).toStringAsFixed(0),
            _formatEta(u.eta),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(FolioRadius.xs),
            child: LinearProgressIndicator(value: progress),
          ),
          const SizedBox(height: 4),
          Text(
            pct,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
