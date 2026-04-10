import 'dart:convert';

import 'block.dart';

/// Versión del formato de archivo `.folio-template`.
const int kFolioTemplateFileVersion = 1;

/// Un template de página guardado en el vault.
class FolioPageTemplate {
  FolioPageTemplate({
    required this.id,
    required this.name,
    required this.blocks,
    this.description = '',
    this.emoji,
    this.category = '',
    int? createdAtMs,
  }) : createdAtMs = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String name;
  String description;
  String? emoji;
  String category;
  final int createdAtMs;
  List<FolioBlock> blocks;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description.isNotEmpty) 'description': description,
    if (emoji != null && emoji!.isNotEmpty) 'emoji': emoji,
    if (category.isNotEmpty) 'category': category,
    'createdAtMs': createdAtMs,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  factory FolioPageTemplate.fromJson(Map<String, dynamic> j) {
    final rawBlocks = (j['blocks'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => FolioBlock.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return FolioPageTemplate(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? 'Template',
      description: j['description'] as String? ?? '',
      emoji: (j['emoji'] as String?)?.trim().isEmpty ?? true
          ? null
          : j['emoji'] as String?,
      category: j['category'] as String? ?? '',
      createdAtMs: (j['createdAtMs'] as num?)?.toInt(),
      blocks: rawBlocks,
    );
  }

  /// Serializa el template como archivo `.folio-template` (JSON).
  String encodeAsFile() => const JsonEncoder.withIndent(
    '  ',
  ).convert({'folioTemplateVersion': kFolioTemplateFileVersion, ...toJson()});

  /// Parsea un archivo `.folio-template`. Devuelve `null` si el formato es inválido.
  static FolioPageTemplate? tryParseFile(String rawJson) {
    try {
      final m = jsonDecode(rawJson);
      if (m is! Map<String, dynamic>) return null;
      if ((m['id'] as String?)?.isEmpty ?? true) return null;
      return FolioPageTemplate.fromJson(m);
    } catch (_) {
      return null;
    }
  }
}
