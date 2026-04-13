import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import 'block.dart';

/// Botón de plantilla: etiqueta + bloques a insertar al pulsar.
class FolioTemplateButtonData {
  FolioTemplateButtonData({
    required this.label,
    required this.blocks,
  });

  final String label;
  final List<FolioBlock> blocks;

  static FolioTemplateButtonData localizedDefault(AppLocalizations l10n) =>
      FolioTemplateButtonData(
        label: l10n.templateButtonDefaultLabel,
        blocks: [
          FolioBlock(
            id: '_tpl',
            type: 'paragraph',
            text: l10n.templateButtonPlaceholderText,
          ),
        ],
      );

  /// Respaldo estable (p. ej. JSON sin etiqueta) sin contexto de UI.
  static FolioTemplateButtonData defaultNew() => localizedDefault(
        lookupAppLocalizations(const Locale('en')),
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
      final label = (m['label'] as String?) ?? 'Template';
      final list = (m['blocks'] as List<dynamic>?) ?? [];
      final blocks = list
          .whereType<Map>()
          .map((e) => FolioBlock.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (blocks.isEmpty) {
        return defaultNew();
      }
      return FolioTemplateButtonData(label: label, blocks: blocks);
    } catch (_) {
      return null;
    }
  }
}
