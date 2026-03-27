import 'dart:convert';

import 'block.dart';

class FolioColumnData {
  FolioColumnData({required this.blocks});

  final List<FolioBlock> blocks;

  factory FolioColumnData.empty() {
    return FolioColumnData(
      blocks: [
        FolioBlock(
          id: 'col_${DateTime.now().microsecondsSinceEpoch}',
          type: 'paragraph',
          text: '',
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  factory FolioColumnData.fromJson(Map<dynamic, dynamic> json) {
    final rawBlocks = json['blocks'] as List<dynamic>? ?? const [];
    final blocks = rawBlocks
        .whereType<Map>()
        .map((raw) => FolioBlock.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
    return FolioColumnData(
      blocks: blocks.isEmpty
          ? [
              FolioBlock(
                id: 'col_${DateTime.now().microsecondsSinceEpoch}',
                type: 'paragraph',
                text: '',
              ),
            ]
          : blocks,
    );
  }
}

/// Contenido de un bloque de columnas (2–3 columnas con bloques mixtos).
class FolioColumnsData {
  FolioColumnsData({required this.columns})
    : assert(columns.length >= 2 && columns.length <= 3);

  final List<FolioColumnData> columns;

  static FolioColumnsData empty() => FolioColumnsData(
    columns: [FolioColumnData.empty(), FolioColumnData.empty()],
  );

  String encode() =>
      jsonEncode({'v': 2, 'columns': columns.map((c) => c.toJson()).toList()});

  static FolioColumnsData? tryParse(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final list = (m['columns'] as List<dynamic>?) ?? [];
      if (list.isEmpty) return FolioColumnsData.empty();
      final cols = list.map((e) {
        if (e is Map) {
          return FolioColumnData.fromJson(e);
        }
        final text = e.toString();
        return FolioColumnData(
          blocks: [
            FolioBlock(
              id: 'col_${DateTime.now().microsecondsSinceEpoch}_${text.hashCode}',
              type: 'paragraph',
              text: text,
            ),
          ],
        );
      }).toList();
      if (cols.length < 2) {
        return FolioColumnsData(
          columns: [cols.elementAt(0), FolioColumnData.empty()],
        );
      }
      if (cols.length > 3) {
        return FolioColumnsData(columns: cols.take(3).toList());
      }
      return FolioColumnsData(columns: cols);
    } catch (_) {
      return null;
    }
  }
}
