import 'meeting_note_bookmark.dart';

class FolioBlockAppearance {
  const FolioBlockAppearance({
    this.textColorRole,
    this.backgroundRole,
    this.fontScale = 1.0,
  });

  final String? textColorRole;
  final String? backgroundRole;
  final double fontScale;

  bool get isDefault =>
      (textColorRole == null || textColorRole!.isEmpty) &&
      (backgroundRole == null || backgroundRole!.isEmpty) &&
      (fontScale - 1.0).abs() < 0.001;

  FolioBlockAppearance normalized() {
    String? normalizeRole(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return null;
      }
      return trimmed;
    }

    final normalizedScale = fontScale.clamp(0.85, 1.45).toDouble();
    return FolioBlockAppearance(
      textColorRole: normalizeRole(textColorRole),
      backgroundRole: normalizeRole(backgroundRole),
      fontScale: (normalizedScale - 1.0).abs() < 0.001 ? 1.0 : normalizedScale,
    );
  }

  static FolioBlockAppearance? normalizeOrNull(
    FolioBlockAppearance? appearance,
  ) {
    if (appearance == null) return null;
    final normalized = appearance.normalized();
    return normalized.isDefault ? null : normalized;
  }

  factory FolioBlockAppearance.fromJson(Map raw) {
    return FolioBlockAppearance(
      textColorRole: (raw['textColorRole'] as String?)?.trim(),
      backgroundRole: (raw['backgroundRole'] as String?)?.trim(),
      fontScale: (raw['fontScale'] as num?)?.toDouble() ?? 1.0,
    ).normalized();
  }

  Map<String, Object?> toJson() {
    final normalizedAppearance = normalized();
    return <String, Object?>{
      if (normalizedAppearance.textColorRole != null)
        'textColorRole': normalizedAppearance.textColorRole,
      if (normalizedAppearance.backgroundRole != null)
        'backgroundRole': normalizedAppearance.backgroundRole,
      if ((normalizedAppearance.fontScale - 1.0).abs() >= 0.001)
        'fontScale': normalizedAppearance.fontScale,
    };
  }
}

class FolioBlock {
  FolioBlock({
    required this.id,
    required this.type,
    required this.text,
    this.richTextDeltaJson,
    this.checked,
    this.expanded,
    this.codeLanguage,
    this.codeWrap,
    this.depth = 0,
    this.icon,
    this.url,
    this.imageWidth,
    this.appearance,
    this.meetingNoteProvider,
    this.meetingNoteTranscriptionEnabled,
    this.meetingNoteTitle,
    this.meetingNoteLanguage,
    this.meetingNoteChannelMeta,
    this.meetingNoteBookmarks,
    this.meetingNotePrepNotes,
    this.meetingNoteMetricsSummary,
    this.meetingNoteAutoAssistEnabled,
    this.meetingNoteSummary,
    this.syncGroupId,
    this.aiGenerated,
  });

  final String id;

  /// paragraph | h1 | h2 | h3 | bullet | numbered | todo | toggle | code | mermaid | equation | image | table | database |
  /// quote | divider | callout | file | video | audio | bookmark | embed | toc | breadcrumb | child_page | template_button | column_list
  String type;

  /// En texto y encabezados puede incluir Markdown inline (negrita, cursiva, código, tachado, subrayado, enlaces).
  String text;

  /// Fuente de verdad WYSIWYG (Quill Delta) serializada como JSON.
  /// Si existe, el editor rich-text debe cargar desde aquí y solo usar [text]
  /// (Markdown) como formato de compatibilidad/export.
  String? richTextDeltaJson;
  bool? checked;

  /// Solo [type] == `toggle`: panel de contenido abierto.
  bool? expanded;

  /// Id de gramática highlight (`dart`, `javascript`, …); solo para `type == 'code'`.
  String? codeLanguage;

  /// wrap option for code blocks
  bool? codeWrap;

  /// Nivel de indentación visual del bloque (default: 0)
  int depth;

  /// Icono opcional para bloques como callout (ej. emoji)
  String? icon;

  /// Ruta de archivo local o URL para bloques de file o video
  String? url;

  /// Ancho relativo para bloques de imagen (0.2 .. 1.0).
  double? imageWidth;

  /// Personalizacion visual persistida para bloques de texto.
  FolioBlockAppearance? appearance;

  /// Proveedor de transcripción para bloques de tipo `meeting_note`.
  /// `null` o `'local'` = Whisper local; `'quill_cloud'` = Quill Cloud.
  String? meetingNoteProvider;

  /// `null` o `true` = generar transcripción; `false` = solo audio (sin Whisper).
  bool? meetingNoteTranscriptionEnabled;

  /// Título opcional de la reunión, distinto del título de la página.
  String? meetingNoteTitle;

  /// Código de locale hint para la transcripción (ej. `es`, `en`).
  String? meetingNoteLanguage;

  /// Metadata de diagnóstico de canales de audio (ej. `{"micChunks": n,
  /// "systemChunks": n, "dualChannel": true}`). Opcional, informativo.
  Map<String, Object?>? meetingNoteChannelMeta;

  /// Marcas de momentos importantes durante la grabación (Fase 4). `null` o
  /// vacío si no hay bookmarks.
  List<MeetingNoteBookmark>? meetingNoteBookmarks;

  /// Notas de preparación (agenda/preguntas/temas) generadas o editadas
  /// antes de la reunión (Fase 6). `null` si no se generó preparación.
  String? meetingNotePrepNotes;

  /// Snapshot final de métricas de conversación al detener la grabación
  /// (Fase 8): `{wordsPerMinute, questionCount, longestMonologueWords,
  /// speakerWordCounts, totalWords}`. Las métricas en vivo se mantienen
  /// efímeras en `MeetingNoteSessionController`, no se persisten por
  /// segundo para no inflar el JSON del vault.
  Map<String, Object?>? meetingNoteMetricsSummary;

  /// `true` si el usuario activó el auto-trigger MCP opt-in (Fase 11) para
  /// este meeting_note. `null`/`false` = desactivado (default).
  bool? meetingNoteAutoAssistEnabled;

  /// Resumen post-reunión estructurado (Fase 13): narrative (String),
  /// keyPoints (lista de String), actionItems (lista de mapas
  /// `{title, taskBlockId}`).
  /// `taskBlockId` de cada action item es `null` hasta que el usuario lo
  /// materializa explícitamente como tarea real (Fase 14) — la extracción
  /// nunca crea tareas por sí sola.
  Map<String, Object?>? meetingNoteSummary;

  /// UUID que identifica el grupo de bloques sincronizados. Todos los bloques
  /// con el mismo [syncGroupId] comparten contenido y se actualizan en cascada.
  String? syncGroupId;

  /// `true` si el bloque fue materializado por Quill (transparencia EU AI Act).
  /// Se limpia al editar el texto manualmente.
  bool? aiGenerated;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'text': text,
    if (richTextDeltaJson != null) 'richTextDeltaJson': richTextDeltaJson,
    if (checked != null) 'checked': checked,
    if (expanded != null) 'expanded': expanded,
    if (codeLanguage != null) 'codeLanguage': codeLanguage,
    if (codeWrap != null) 'codeWrap': codeWrap,
    if (depth > 0) 'depth': depth,
    if (icon != null) 'icon': icon,
    if (url != null) 'url': url,
    if (imageWidth != null && imageWidth != 1.0) 'imageWidth': imageWidth,
    if (appearance != null && !appearance!.isDefault)
      'appearance': appearance!.toJson(),
    if (meetingNoteProvider != null) 'meetingNoteProvider': meetingNoteProvider,
    if (meetingNoteTranscriptionEnabled == false)
      'meetingNoteTranscriptionEnabled': false,
    if (meetingNoteTitle != null) 'meetingNoteTitle': meetingNoteTitle,
    if (meetingNoteLanguage != null) 'meetingNoteLanguage': meetingNoteLanguage,
    if (meetingNoteChannelMeta != null)
      'meetingNoteChannelMeta': meetingNoteChannelMeta,
    if (MeetingNoteBookmark.listToJson(meetingNoteBookmarks) != null)
      'meetingNoteBookmarks': MeetingNoteBookmark.listToJson(
        meetingNoteBookmarks,
      ),
    if (meetingNotePrepNotes != null)
      'meetingNotePrepNotes': meetingNotePrepNotes,
    if (meetingNoteMetricsSummary != null)
      'meetingNoteMetricsSummary': meetingNoteMetricsSummary,
    if (meetingNoteAutoAssistEnabled == true)
      'meetingNoteAutoAssistEnabled': true,
    if (meetingNoteSummary != null) 'meetingNoteSummary': meetingNoteSummary,
    if (syncGroupId != null) 'syncGroupId': syncGroupId,
    if (aiGenerated == true) 'aiGenerated': true,
  };

  static int _fallbackIdCounter = 0;

  /// Lee un id de bloque de forma tolerante: acepta strings, numérico legacy o
  /// nulo (genera un id de reserva) sin lanzar `CastError` que rompería la carga
  /// completa del vault.
  static String _readId(Object? raw) {
    if (raw is String && raw.isNotEmpty) return raw;
    final asStr = raw?.toString();
    if (asStr != null && asStr.isNotEmpty) return asStr;
    return 'block_fallback_${DateTime.now().microsecondsSinceEpoch}_'
        '${_fallbackIdCounter++}';
  }

  factory FolioBlock.fromJson(Map<String, dynamic> j) {
    return FolioBlock(
      id: _readId(j['id']),
      type: j['type'] as String? ?? 'paragraph',
      text: j['text'] as String? ?? '',
      richTextDeltaJson: j['richTextDeltaJson'] as String?,
      checked: j['checked'] as bool?,
      expanded: j['expanded'] as bool?,
      codeLanguage: j['codeLanguage'] as String?,
      codeWrap: j['codeWrap'] as bool?,
      depth: j['depth'] as int? ?? 0,
      icon: j['icon'] as String?,
      url: j['url'] as String?,
      imageWidth: (j['imageWidth'] as num?)?.toDouble(),
      appearance: j['appearance'] is Map
          ? FolioBlockAppearance.fromJson(j['appearance'] as Map)
          : null,
      meetingNoteProvider: j['meetingNoteProvider'] as String?,
      meetingNoteTranscriptionEnabled:
          j['meetingNoteTranscriptionEnabled'] as bool?,
      meetingNoteTitle: j['meetingNoteTitle'] as String?,
      meetingNoteLanguage: j['meetingNoteLanguage'] as String?,
      meetingNoteChannelMeta: j['meetingNoteChannelMeta'] is Map
          ? Map<String, Object?>.from(j['meetingNoteChannelMeta'] as Map)
          : null,
      meetingNoteBookmarks: j['meetingNoteBookmarks'] == null
          ? null
          : MeetingNoteBookmark.listFromJson(j['meetingNoteBookmarks']),
      meetingNotePrepNotes: j['meetingNotePrepNotes'] as String?,
      meetingNoteMetricsSummary: j['meetingNoteMetricsSummary'] is Map
          ? Map<String, Object?>.from(j['meetingNoteMetricsSummary'] as Map)
          : null,
      meetingNoteAutoAssistEnabled: j['meetingNoteAutoAssistEnabled'] as bool?,
      meetingNoteSummary: j['meetingNoteSummary'] is Map
          ? Map<String, Object?>.from(j['meetingNoteSummary'] as Map)
          : null,
      syncGroupId: j['syncGroupId'] as String?,
      aiGenerated: j['aiGenerated'] as bool?,
    );
  }

  FolioBlock copyWith({
    String? text,
    String? type,
    String? richTextDeltaJson,
    bool? checked,
    bool? expanded,
    String? codeLanguage,
    bool? codeWrap,
    int? depth,
    String? icon,
    String? url,
    double? imageWidth,
    FolioBlockAppearance? appearance,
    String? meetingNoteProvider,
    bool? meetingNoteTranscriptionEnabled,
    String? meetingNoteTitle,
    String? meetingNoteLanguage,
    Map<String, Object?>? meetingNoteChannelMeta,
    List<MeetingNoteBookmark>? meetingNoteBookmarks,
    String? meetingNotePrepNotes,
    Map<String, Object?>? meetingNoteMetricsSummary,
    bool? meetingNoteAutoAssistEnabled,
    Map<String, Object?>? meetingNoteSummary,
    String? syncGroupId,
    bool clearSyncGroupId = false,
    bool? aiGenerated,
    bool clearAiGenerated = false,
  }) {
    return FolioBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      richTextDeltaJson: richTextDeltaJson ?? this.richTextDeltaJson,
      checked: checked ?? this.checked,
      expanded: expanded ?? this.expanded,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      codeWrap: codeWrap ?? this.codeWrap,
      depth: depth ?? this.depth,
      icon: icon ?? this.icon,
      url: url ?? this.url,
      imageWidth: imageWidth ?? this.imageWidth,
      appearance: appearance ?? this.appearance,
      meetingNoteProvider: meetingNoteProvider ?? this.meetingNoteProvider,
      meetingNoteTranscriptionEnabled:
          meetingNoteTranscriptionEnabled ??
          this.meetingNoteTranscriptionEnabled,
      meetingNoteTitle: meetingNoteTitle ?? this.meetingNoteTitle,
      meetingNoteLanguage: meetingNoteLanguage ?? this.meetingNoteLanguage,
      meetingNoteChannelMeta:
          meetingNoteChannelMeta ?? this.meetingNoteChannelMeta,
      meetingNoteBookmarks:
          meetingNoteBookmarks ?? this.meetingNoteBookmarks,
      meetingNotePrepNotes:
          meetingNotePrepNotes ?? this.meetingNotePrepNotes,
      meetingNoteMetricsSummary:
          meetingNoteMetricsSummary ?? this.meetingNoteMetricsSummary,
      meetingNoteAutoAssistEnabled:
          meetingNoteAutoAssistEnabled ?? this.meetingNoteAutoAssistEnabled,
      meetingNoteSummary: meetingNoteSummary ?? this.meetingNoteSummary,
      syncGroupId: clearSyncGroupId ? null : (syncGroupId ?? this.syncGroupId),
      aiGenerated: clearAiGenerated ? null : (aiGenerated ?? this.aiGenerated),
    );
  }
}

/// Si se permite fusionar [cur] en [prev] con retroceso al inicio de línea.
bool folioBlocksCanMerge(FolioBlock prev, FolioBlock cur) {
  const structural = {
    'image',
    'table',
    'database',
    'kanban',
    'canvas',
    'mermaid',
    'bookmark',
    'embed',
    'audio',
    'video',
    'file',
    'divider',
    'toc',
    'breadcrumb',
    'child_page',
    'template_button',
    'column_list',
    'toggle',
    'meeting_note',
  };
  if (structural.contains(prev.type) || structural.contains(cur.type)) {
    return false;
  }
  if (prev.type == 'code' || cur.type == 'code') {
    return prev.type == 'code' && cur.type == 'code';
  }
  if (prev.type == 'equation' || cur.type == 'equation') {
    return prev.type == 'equation' && cur.type == 'equation';
  }
  return true;
}
