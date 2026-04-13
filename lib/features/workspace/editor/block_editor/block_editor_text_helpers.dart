import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../block_type_catalog.dart';

/// `null` si el texto del bloque no es comando `/…`; si no, filtro tras la `/` (puede ser vacío).
String? slashFilterFromBlockText(String text) {
  if (!text.startsWith('/')) return null;
  if (text.contains('\n')) return null;
  final tail = text.substring(1);
  if (tail.contains(' ')) return null;
  return tail;
}

int? mentionTriggerStartFromSelection(String text, TextSelection selection) {
  if (!selection.isValid || !selection.isCollapsed) return null;
  final caret = selection.baseOffset;
  if (caret <= 0 || caret > text.length) return null;
  var start = caret - 1;
  while (start >= 0) {
    final code = text.codeUnitAt(start);
    if (code == 0x20 || code == 0x0A || code == 0x0D || code == 0x09) {
      break;
    }
    start--;
  }
  start += 1;
  if (start >= caret) return null;
  if (text.codeUnitAt(start) != 0x40 /* @ */) return null;
  final tail = text.substring(start + 1, caret);
  if (tail.contains(RegExp(r'[\[\]\(\)]'))) return null;
  return start;
}

String? mentionFilterFromSelection(String text, TextSelection selection) {
  final start = mentionTriggerStartFromSelection(text, selection);
  if (start == null) return null;
  final caret = selection.baseOffset;
  return text.substring(start + 1, caret);
}

bool usesCodeControllerForBlockType(String type) =>
    type == 'code' || type == 'mermaid' || type == 'equation';

List<BlockTypeDef> catalogFiltered(String q, AppLocalizations l10n) {
  return filterBlockTypeCatalog(q, l10n);
}
