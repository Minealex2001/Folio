import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../block_type_catalog.dart';

/// Cola tras `/` permitida para comandos [Quill] (`/ai`, `/ai resumir`, `/airesumir`).
///
/// Reglas: solo un espacio entre `ai` y una única palabra subsiguiente; sin más espacios.
bool slashAiTailIsValid(String afterSlash) {
  final t = afterSlash.trimRight();
  if (t.isEmpty) return true;
  if (t.length == 1) {
    return t == 'a' || t == 'i';
  }
  if (!t.startsWith('ai')) return false;
  final rest = t.substring(2);
  if (rest.isEmpty) return true;
  if (rest.startsWith(' ')) {
    final word = rest.substring(1).trimLeft();
    if (word.isEmpty) return true;
    return !word.contains(RegExp(r'\s'));
  }
  return !rest.contains(RegExp(r'\s'));
}

/// Filtro en minúsculas para el catálogo `/` (coincidencia con key/label/hint).
String slashCatalogFilterFromAfterSlash(String afterSlash) {
  return afterSlash.trim().toLowerCase();
}

/// `null` si el texto del bloque no es comando `/…`; si no, filtro para el catálogo.
String? slashFilterFromBlockText(String text) {
  final t = text.replaceAll(RegExp(r'[\r\n]+$'), '');
  if (!t.startsWith('/')) return null;
  if (t.contains('\n') || t.contains('\r')) return null;
  final afterSlash = t.substring(1);
  if (slashAiTailIsValid(afterSlash)) {
    return slashCatalogFilterFromAfterSlash(afterSlash);
  }
  if (afterSlash.contains(' ')) return null;
  return slashCatalogFilterFromAfterSlash(afterSlash);
}

/// Filtro `/comando` usando la **línea del cursor** en texto plano (p. ej. Quill).
///
/// Permite varias líneas en el bloque mientras el `/…` está en la línea activa.
String? slashFilterFromPlainTextAndSelection(
  String plain,
  TextSelection selection,
) {
  if (!selection.isValid || !selection.isCollapsed) return null;
  final caret = selection.baseOffset.clamp(0, plain.length);
  var lineStart = 0;
  for (var i = caret - 1; i >= 0; i--) {
    final ch = plain.codeUnitAt(i);
    if (ch == 0x0A || ch == 0x0D) {
      lineStart = i + 1;
      if (ch == 0x0D &&
          lineStart < plain.length &&
          plain.codeUnitAt(lineStart) == 0x0A) {
        lineStart++;
      }
      break;
    }
  }
  var lineEnd = plain.length;
  for (var i = caret; i < plain.length; i++) {
    final ch = plain.codeUnitAt(i);
    if (ch == 0x0A || ch == 0x0D) {
      lineEnd = i;
      break;
    }
  }
  if (lineEnd < lineStart) return null;
  var line = plain.substring(lineStart, lineEnd);
  if (line.endsWith('\r')) {
    line = line.substring(0, line.length - 1);
  }
  if (!line.startsWith('/')) return null;
  final relCaret = caret - lineStart;
  if (relCaret < 1) {
    return '';
  }
  final prefix = line.substring(0, relCaret);
  if (!prefix.startsWith('/')) return null;
  final afterSlash = prefix.substring(1);
  if (slashAiTailIsValid(afterSlash)) {
    return slashCatalogFilterFromAfterSlash(afterSlash);
  }
  if (afterSlash.contains(' ')) return null;
  return slashCatalogFilterFromAfterSlash(afterSlash);
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
