class LocalProfile {
  LocalProfile({required this.id, required this.name});

  final String id;
  String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory LocalProfile.fromJson(Map<String, dynamic> j) {
    return LocalProfile(
      id: j['id'] as String,
      name: j['name'] as String? ?? 'Perfil',
    );
  }
}

class LocalPageComment {
  LocalPageComment({
    required this.id,
    required this.pageId,
    required this.authorProfileId,
    required this.text,
    required this.createdAtMs,
    this.blockId,
  });

  final String id;
  final String pageId;
  final String authorProfileId;
  String text;
  final int createdAtMs;
  String? blockId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'pageId': pageId,
    'authorProfileId': authorProfileId,
    'text': text,
    'createdAtMs': createdAtMs,
    if (blockId != null) 'blockId': blockId,
  };

  factory LocalPageComment.fromJson(Map<String, dynamic> j) {
    return LocalPageComment(
      id: j['id'] as String,
      pageId: j['pageId'] as String,
      authorProfileId: j['authorProfileId'] as String? ?? 'local-default',
      text: j['text'] as String? ?? '',
      createdAtMs: (j['createdAtMs'] as num?)?.toInt() ?? 0,
      blockId: j['blockId'] as String?,
    );
  }
}
