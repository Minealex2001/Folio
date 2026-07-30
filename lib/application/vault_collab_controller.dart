import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/block.dart';
import '../models/folio_page.dart';
import '../models/local_collab.dart';

/// Estado y coordinación de colaboración en tiempo real por página: sala,
/// código de invitación, snapshots remotos y archivado de chat como
/// comentarios locales. Punto de extensión para presencia/cursores, chat y
/// sincronización CRDT (ver docs/ARCHITECTURE.md, salas de colaboración).
class VaultCollabController extends ChangeNotifier {
  VaultCollabController({
    required FolioPage? Function(String id) pageProvider,
    required void Function({String? trackRevisionForPageId, bool notify})
    scheduleSave,
    required bool Function() canMutateEncryptedContent,
    required void Function() bumpContentEpoch,
    required Iterable<LocalPageComment> Function() commentsProvider,
    required void Function(LocalPageComment comment) addComment,
  }) : _pageProvider = pageProvider,
       _scheduleSave = scheduleSave,
       _canMutateEncryptedContent = canMutateEncryptedContent,
       _bumpContentEpoch = bumpContentEpoch,
       _commentsProvider = commentsProvider,
       _addComment = addComment;

  static const _uuid = Uuid();

  final FolioPage? Function(String id) _pageProvider;
  final void Function({String? trackRevisionForPageId, bool notify})
  _scheduleSave;
  final bool Function() _canMutateEncryptedContent;
  final void Function() _bumpContentEpoch;
  final Iterable<LocalPageComment> Function() _commentsProvider;
  final void Function(LocalPageComment comment) _addComment;

  void setPageCollabRoomId(String pageId, String? roomId, {String? joinCode}) {
    final p = _pageProvider(pageId);
    if (p == null) return;
    final next = roomId?.trim();
    p.collabRoomId = (next == null || next.isEmpty) ? null : next;
    if (p.collabRoomId == null) {
      p.collabJoinCode = null;
    } else if (joinCode != null) {
      final c = joinCode.trim();
      p.collabJoinCode = c.isEmpty ? null : c;
    }
    notifyListeners();
    _scheduleSave();
  }

  void setPageCollabJoinCode(String pageId, String? joinCode) {
    final p = _pageProvider(pageId);
    if (p == null) return;
    final c = joinCode?.trim();
    p.collabJoinCode = (c == null || c.isEmpty) ? null : c;
    notifyListeners();
    _scheduleSave();
  }

  /// Aplica estado remoto de colaboración (sin deshacer local explícito).
  ///
  /// Sustituye título y bloques por el snapshot remoto. Si el par remoto
  /// está desactualizado, un bloque de texto (p. ej. cita) puede verse vacío
  /// hasta la siguiente sincronización; el editor alineará controladores en
  /// el siguiente frame.
  void applyRemoteCollabPageState({
    required String pageId,
    required String title,
    required List<FolioBlock> blocks,
  }) {
    if (!_canMutateEncryptedContent()) return;
    final page = _pageProvider(pageId);
    if (page == null) return;
    page.title = title;
    page.blocks = blocks;
    _bumpContentEpoch();
    notifyListeners();
    _scheduleSave(trackRevisionForPageId: pageId);
  }

  /// Archiva mensajes del chat de colaboración como comentarios locales de la página.
  void archiveCollabChatToComments({
    required String pageId,
    required List<
      ({
        String messageId,
        String authorUid,
        String authorName,
        String text,
        int createdAtMs,
      })
    >
    messages,
  }) {
    if (!_canMutateEncryptedContent()) return;
    if (_pageProvider(pageId) == null) return;
    final existing = _commentsProvider()
        .where((c) => c.pageId == pageId)
        .map((c) => c.collabMessageId)
        .whereType<String>()
        .toSet();
    for (final m in messages) {
      if (existing.contains(m.messageId)) continue;
      _addComment(
        LocalPageComment(
          id: _uuid.v4(),
          pageId: pageId,
          authorProfileId: m.authorUid,
          text: m.text,
          createdAtMs: m.createdAtMs,
          collabMessageId: m.messageId,
          authorDisplayName: m.authorName,
        ),
      );
    }
    notifyListeners();
    _scheduleSave();
  }
}
