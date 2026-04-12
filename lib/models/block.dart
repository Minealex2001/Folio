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
    this.checked,
    this.expanded,
    this.codeLanguage,
    this.depth = 0,
    this.icon,
    this.url,
    this.imageWidth,
    this.appearance,
    this.meetingNoteProvider,
  });

  final String id;

  /// paragraph | h1 | h2 | h3 | bullet | numbered | todo | toggle | code | mermaid | equation | image | table | database |
  /// quote | divider | callout | file | video | audio | bookmark | embed | toc | breadcrumb | child_page | template_button | column_list
  String type;

  /// En texto y encabezados puede incluir Markdown inline (negrita, cursiva, código, tachado, subrayado, enlaces).
  String text;
  bool? checked;

  /// Solo [type] == `toggle`: panel de contenido abierto.
  bool? expanded;

  /// Id de gramática highlight (`dart`, `javascript`, …); solo para `type == 'code'`.
  String? codeLanguage;

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'text': text,
    if (checked != null) 'checked': checked,
    if (expanded != null) 'expanded': expanded,
    if (codeLanguage != null) 'codeLanguage': codeLanguage,
    if (depth > 0) 'depth': depth,
    if (icon != null) 'icon': icon,
    if (url != null) 'url': url,
    if (imageWidth != null && imageWidth != 1.0) 'imageWidth': imageWidth,
    if (appearance != null && !appearance!.isDefault)
      'appearance': appearance!.toJson(),
    if (meetingNoteProvider != null) 'meetingNoteProvider': meetingNoteProvider,
  };

  factory FolioBlock.fromJson(Map<String, dynamic> j) {
    return FolioBlock(
      id: j['id'] as String,
      type: j['type'] as String? ?? 'paragraph',
      text: j['text'] as String? ?? '',
      checked: j['checked'] as bool?,
      expanded: j['expanded'] as bool?,
      codeLanguage: j['codeLanguage'] as String?,
      depth: j['depth'] as int? ?? 0,
      icon: j['icon'] as String?,
      url: j['url'] as String?,
      imageWidth: (j['imageWidth'] as num?)?.toDouble(),
      appearance: j['appearance'] is Map
          ? FolioBlockAppearance.fromJson(j['appearance'] as Map)
          : null,
      meetingNoteProvider: j['meetingNoteProvider'] as String?,
    );
  }

  FolioBlock copyWith({
    String? text,
    String? type,
    bool? checked,
    bool? expanded,
    String? codeLanguage,
    int? depth,
    String? icon,
    String? url,
    double? imageWidth,
    FolioBlockAppearance? appearance,
    String? meetingNoteProvider,
  }) {
    return FolioBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      checked: checked ?? this.checked,
      expanded: expanded ?? this.expanded,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      depth: depth ?? this.depth,
      icon: icon ?? this.icon,
      url: url ?? this.url,
      imageWidth: imageWidth ?? this.imageWidth,
      appearance: appearance ?? this.appearance,
      meetingNoteProvider: meetingNoteProvider ?? this.meetingNoteProvider,
    );
  }
}

/// Si se permite fusionar [cur] en [prev] con retroceso al inicio de línea.
bool folioBlocksCanMerge(FolioBlock prev, FolioBlock cur) {
  const structural = {
    'image',
    'table',
    'database',
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
