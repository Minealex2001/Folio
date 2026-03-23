import 'block.dart';

class FolioPage {
  FolioPage({
    required this.id,
    required this.title,
    this.parentId,
    List<FolioBlock>? blocks,
  }) : blocks = (blocks != null && blocks.isNotEmpty)
            ? blocks
            : [
                FolioBlock(
                  id: '${id}_b0',
                  type: 'paragraph',
                  text: '',
                ),
              ];

  final String id;
  String title;
  /// null = raíz del árbol
  String? parentId;
  List<FolioBlock> blocks;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (parentId != null) 'parentId': parentId,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory FolioPage.fromJson(Map<String, dynamic> j) {
    final rawBlocks = j['blocks'] as List<dynamic>?;
    final blocks = rawBlocks == null || rawBlocks.isEmpty
        ? null
        : rawBlocks
            .map((e) => FolioBlock.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
    final id = j['id'] as String;
    return FolioPage(
      id: id,
      title: j['title'] as String? ?? 'Sin título',
      parentId: j['parentId'] as String?,
      blocks: blocks,
    );
  }

  /// Texto plano concatenado (búsqueda / migración).
  String get plainTextContent =>
      blocks.map((b) => b.text).join('\n').trimRight();

  void syncPlainFallback(String content) {
    if (blocks.isEmpty) {
      blocks.add(FolioBlock(id: '${id}_b0', type: 'paragraph', text: content));
    } else if (blocks.length == 1 && blocks.first.type == 'paragraph') {
      blocks[0].text = content;
    }
  }
}
