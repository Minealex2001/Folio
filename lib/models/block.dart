class FolioBlock {
  FolioBlock({
    required this.id,
    required this.type,
    required this.text,
    this.checked,
    this.codeLanguage,
    this.depth = 0,
    this.icon,
    this.url,
    this.imageWidth,
  });

  final String id;

  /// paragraph | h1 | h2 | h3 | bullet | todo | code | image | table | database | quote | divider | callout | file | video
  String type;

  /// En texto y encabezados puede incluir Markdown inline (negrita, cursiva, código, tachado, subrayado, enlaces).
  String text;
  bool? checked;

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'text': text,
    if (checked != null) 'checked': checked,
    if (codeLanguage != null) 'codeLanguage': codeLanguage,
    if (depth > 0) 'depth': depth,
    if (icon != null) 'icon': icon,
    if (url != null) 'url': url,
    if (imageWidth != null && imageWidth != 1.0) 'imageWidth': imageWidth,
  };

  factory FolioBlock.fromJson(Map<String, dynamic> j) {
    return FolioBlock(
      id: j['id'] as String,
      type: j['type'] as String? ?? 'paragraph',
      text: j['text'] as String? ?? '',
      checked: j['checked'] as bool?,
      codeLanguage: j['codeLanguage'] as String?,
      depth: j['depth'] as int? ?? 0,
      icon: j['icon'] as String?,
      url: j['url'] as String?,
      imageWidth: (j['imageWidth'] as num?)?.toDouble(),
    );
  }

  FolioBlock copyWith({
    String? text,
    String? type,
    bool? checked,
    String? codeLanguage,
    int? depth,
    String? icon,
    String? url,
    double? imageWidth,
  }) {
    return FolioBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      checked: checked ?? this.checked,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      depth: depth ?? this.depth,
      icon: icon ?? this.icon,
      url: url ?? this.url,
      imageWidth: imageWidth ?? this.imageWidth,
    );
  }
}

/// Si se permite fusionar [cur] en [prev] con retroceso al inicio de línea.
bool folioBlocksCanMerge(FolioBlock prev, FolioBlock cur) {
  const structural = {'image', 'table', 'database'};
  if (structural.contains(prev.type) || structural.contains(cur.type)) {
    return false;
  }
  if (prev.type == 'code' || cur.type == 'code') {
    return prev.type == 'code' && cur.type == 'code';
  }
  return true;
}
