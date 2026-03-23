class FolioBlock {
  FolioBlock({
    required this.id,
    required this.type,
    required this.text,
    this.checked,
    this.codeLanguage,
  });

  final String id;

  /// paragraph | h1 | h2 | h3 | bullet | todo | code | image | table
  String type;

  /// En texto y encabezados puede incluir Markdown inline (negrita, cursiva, código, tachado, subrayado, enlaces).
  String text;
  bool? checked;

  /// Id de gramática highlight (`dart`, `javascript`, …); solo para `type == 'code'`.
  String? codeLanguage;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'text': text,
    if (checked != null) 'checked': checked,
    if (codeLanguage != null) 'codeLanguage': codeLanguage,
  };

  factory FolioBlock.fromJson(Map<String, dynamic> j) {
    return FolioBlock(
      id: j['id'] as String,
      type: j['type'] as String? ?? 'paragraph',
      text: j['text'] as String? ?? '',
      checked: j['checked'] as bool?,
      codeLanguage: j['codeLanguage'] as String?,
    );
  }

  FolioBlock copyWith({
    String? text,
    String? type,
    bool? checked,
    String? codeLanguage,
  }) {
    return FolioBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      checked: checked ?? this.checked,
      codeLanguage: codeLanguage ?? this.codeLanguage,
    );
  }
}

/// Si se permite fusionar [cur] en [prev] con retroceso al inicio de línea.
bool folioBlocksCanMerge(FolioBlock prev, FolioBlock cur) {
  const structural = {'image', 'table'};
  if (structural.contains(prev.type) || structural.contains(cur.type)) {
    return false;
  }
  if (prev.type == 'code' || cur.type == 'code') {
    return prev.type == 'code' && cur.type == 'code';
  }
  return true;
}
