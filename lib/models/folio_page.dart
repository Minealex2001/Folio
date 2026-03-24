import 'block.dart';
import 'folio_table_data.dart';

class FolioPage {
  FolioPage({
    required this.id,
    required this.title,
    this.parentId,
    List<FolioBlock>? blocks,
  }) : blocks = (blocks != null && blocks.isNotEmpty)
           ? blocks
           : [FolioBlock(id: '${id}_b0', type: 'paragraph', text: '')];

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
              .map(
                (e) => FolioBlock.fromJson(Map<String, dynamic>.from(e as Map)),
              )
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
      blocks.map(_folioBlockPlainText).join('\n').trimRight();

  void syncPlainFallback(String content) {
    if (blocks.isEmpty) {
      blocks.add(FolioBlock(id: '${id}_b0', type: 'paragraph', text: content));
    } else if (blocks.length == 1 && blocks.first.type == 'paragraph') {
      blocks[0].text = content;
    }
  }
}

/// Misma lógica que [FolioPage.plainTextContent] para JSON de bloques (revisiones).
String folioPlainTextFromBlocksJson(List<Map<String, dynamic>> blocksJson) {
  return blocksJson
      .map((m) => _folioBlockPlainText(FolioBlock.fromJson(m)))
      .join('\n')
      .trimRight();
}

String _folioBlockPlainText(FolioBlock b) {
  switch (b.type) {
    case 'image':
      return b.text.trim().isEmpty ? '' : '[imagen] ${b.text.trim()}';
    case 'file':
      final u = b.url?.trim() ?? '';
      return u.isEmpty ? '' : '[archivo] $u';
    case 'video':
      final u = b.url?.trim() ?? '';
      return u.isEmpty ? '' : '[video] $u';
    case 'table':
      return FolioTableData.plainTextFromJson(b.text);
    case 'code':
      final lang = b.codeLanguage?.trim();
      if (lang == null || lang.isEmpty) return b.text;
      return '[code:$lang]\n${b.text}';
    default:
      return b.text;
  }
}
