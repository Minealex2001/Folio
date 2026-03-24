import 'block.dart';
import 'folio_database_data.dart';
import 'folio_page_import_info.dart';
import 'folio_table_data.dart';

class FolioPage {
  FolioPage({
    required this.id,
    required this.title,
    this.parentId,
    this.lastImportInfo,
    List<FolioBlock>? blocks,
  }) : blocks = (blocks != null && blocks.isNotEmpty)
           ? blocks
           : [FolioBlock(id: '${id}_b0', type: 'paragraph', text: '')];

  final String id;
  String title;

  /// null = raíz del árbol
  String? parentId;
  FolioPageImportInfo? lastImportInfo;
  List<FolioBlock> blocks;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (parentId != null) 'parentId': parentId,
    if (lastImportInfo != null) 'lastImportInfo': lastImportInfo!.toJson(),
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
      title: j['title'] as String? ?? 'Untitled',
      parentId: j['parentId'] as String?,
      lastImportInfo: j['lastImportInfo'] is Map<String, dynamic>
          ? FolioPageImportInfo.fromJson(
              j['lastImportInfo'] as Map<String, dynamic>,
            )
          : (j['lastImportInfo'] is Map
                ? FolioPageImportInfo.fromJson(
                    Map<String, dynamic>.from(j['lastImportInfo'] as Map),
                  )
                : null),
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
    case 'bookmark':
      final u = b.url?.trim() ?? '';
      final t = b.text.trim();
      if (u.isEmpty) return t.isEmpty ? '' : '[bookmark] $t';
      return t.isEmpty ? '[bookmark] $u' : '[bookmark] $t $u';
    case 'embed':
      final u = b.url?.trim() ?? '';
      return u.isEmpty ? '' : '[embed] $u';
    case 'audio':
      final u = b.url?.trim() ?? '';
      return u.isEmpty ? '' : '[audio] $u';
    case 'child_page':
      final id = b.text.trim();
      return id.isEmpty ? '' : '[página] $id';
    case 'template_button':
      return '[plantilla]';
    case 'toc':
      return '[índice]';
    case 'breadcrumb':
      return '[migas]';
    case 'column_list':
      return '[columnas]';
    case 'equation':
      return b.text.trim().isEmpty ? '' : '[ecuación] ${b.text.trim()}';
    case 'toggle':
      return b.text.trim().isEmpty ? '' : '[toggle] ${b.text.trim()}';
    case 'numbered':
      return b.text;
    case 'table':
      return FolioTableData.plainTextFromJson(b.text);
    case 'database':
      return FolioDatabaseData.plainTextFromJson(b.text);
    case 'code':
      final lang = b.codeLanguage?.trim();
      if (lang == null || lang.isEmpty) return b.text;
      return '[code:$lang]\n${b.text}';
    default:
      return b.text;
  }
}
