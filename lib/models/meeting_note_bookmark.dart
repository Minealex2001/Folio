/// Marca de un momento durante una grabación de `meeting_note` (Fase 4 de
/// la evolución del bloque, inspirada en el bookmarking de Call.md).
///
/// Se almacena en [FolioBlock.meetingNoteBookmarks] como lista de mapas
/// JSON — mismo patrón que otros datos estructurados embebidos en bloques
/// (ver `FolioTaskData`).
enum MeetingNoteBookmarkType { important, decision, actionItem, question, note }

MeetingNoteBookmarkType _bookmarkTypeFromJson(String? raw) {
  switch (raw) {
    case 'decision':
      return MeetingNoteBookmarkType.decision;
    case 'actionItem':
      return MeetingNoteBookmarkType.actionItem;
    case 'question':
      return MeetingNoteBookmarkType.question;
    case 'note':
      return MeetingNoteBookmarkType.note;
    case 'important':
    default:
      return MeetingNoteBookmarkType.important;
  }
}

String _bookmarkTypeToJson(MeetingNoteBookmarkType type) => switch (type) {
  MeetingNoteBookmarkType.important => 'important',
  MeetingNoteBookmarkType.decision => 'decision',
  MeetingNoteBookmarkType.actionItem => 'actionItem',
  MeetingNoteBookmarkType.question => 'question',
  MeetingNoteBookmarkType.note => 'note',
};

class MeetingNoteBookmark {
  MeetingNoteBookmark({
    required this.id,
    required this.timestampMs,
    required this.type,
    this.label = '',
    this.createdAtMs,
  });

  final String id;

  /// Offset en milisegundos desde el inicio de la grabación.
  final int timestampMs;

  final MeetingNoteBookmarkType type;

  /// Texto/contexto opcional asociado a la marca.
  final String label;

  /// Epoch ms de creación; opcional (no crítico, solo informativo).
  final int? createdAtMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'timestampMs': timestampMs,
    'type': _bookmarkTypeToJson(type),
    if (label.isNotEmpty) 'label': label,
    if (createdAtMs != null) 'createdAtMs': createdAtMs,
  };

  factory MeetingNoteBookmark.fromJson(Map<String, dynamic> j) {
    return MeetingNoteBookmark(
      id: (j['id'] as String?)?.trim().isNotEmpty == true
          ? j['id'] as String
          : DateTime.now().microsecondsSinceEpoch.toString(),
      timestampMs: (j['timestampMs'] as num?)?.toInt() ?? 0,
      type: _bookmarkTypeFromJson(j['type'] as String?),
      label: (j['label'] as String?)?.trim() ?? '',
      createdAtMs: (j['createdAtMs'] as num?)?.toInt(),
    );
  }

  static List<MeetingNoteBookmark> listFromJson(Object? raw) {
    if (raw is! List) return const <MeetingNoteBookmark>[];
    return raw
        .whereType<Map>()
        .map((m) => MeetingNoteBookmark.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  static List<Map<String, Object?>>? listToJson(
    List<MeetingNoteBookmark>? bookmarks,
  ) {
    if (bookmarks == null || bookmarks.isEmpty) return null;
    return bookmarks.map((b) => b.toJson()).toList(growable: false);
  }
}
