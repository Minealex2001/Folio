import 'dart:convert';

import 'block.dart';

/// Botón de plantilla: etiqueta + bloques a insertar al pulsar.
class FolioTemplateButtonData {
  FolioTemplateButtonData({
    required this.label,
    required this.blocks,
  });

  final String label;
  final List<FolioBlock> blocks;

  static FolioTemplateButtonData defaultNew() => FolioTemplateButtonData(
        label: 'Plantilla',
        blocks: [
          FolioBlock(
            id: '_tpl',
            type: 'paragraph',
            text: 'Texto de la plantilla…',
          ),
        ],
      );

  String encode() => jsonEncode({
        'v': 1,
        'label': label,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      });

  static FolioTemplateButtonData? tryParse(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final label = (m['label'] as String?) ?? 'Plantilla';
      final list = (m['blocks'] as List<dynamic>?) ?? [];
      final blocks = list
          .whereType<Map>()
          .map((e) => FolioBlock.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (blocks.isEmpty) {
        return FolioTemplateButtonData.defaultNew();
      }
      return FolioTemplateButtonData(label: label, blocks: blocks);
    } catch (_) {
      return null;
    }
  }
}
