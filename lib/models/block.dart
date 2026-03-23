class FolioBlock {
  FolioBlock({
    required this.id,
    required this.type,
    required this.text,
    this.checked,
  });

  final String id;
  /// paragraph | h1 | h2 | h3 | bullet | todo
  String type;
  String text;
  bool? checked;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'text': text,
        if (checked != null) 'checked': checked,
      };

  factory FolioBlock.fromJson(Map<String, dynamic> j) {
    return FolioBlock(
      id: j['id'] as String,
      type: j['type'] as String? ?? 'paragraph',
      text: j['text'] as String? ?? '',
      checked: j['checked'] as bool?,
    );
  }

  FolioBlock copyWith({String? text, String? type, bool? checked}) {
    return FolioBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      checked: checked ?? this.checked,
    );
  }
}
