import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../editor/folio_mermaid_preview.dart';

/// Sustituye bloques ```mermaid por [FolioMermaidPreview]; el resto de `pre` sigue el render por defecto.
class FolioMermaidMarkdownBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (element.tag != 'pre') return null;
    if (_fencedLanguageFromPre(element) != 'mermaid') return null;
    final src = _extractPreText(element);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: FolioMermaidPreview(source: src, maxHeight: 300),
    );
  }
}

String? _fencedLanguageFromPre(md.Element pre) {
  for (final c in pre.children ?? const <md.Node>[]) {
    if (c is! md.Element) continue;
    if (c.tag != 'code') continue;
    final cls = c.attributes['class'] ?? '';
    if (cls.contains('language-mermaid')) return 'mermaid';
  }
  return null;
}

String _extractPreText(md.Element pre) {
  final buf = StringBuffer();
  void walk(md.Node n) {
    if (n is md.Text) {
      buf.write(n.text);
    } else if (n is md.Element) {
      for (final c in n.children ?? const <md.Node>[]) {
        walk(c);
      }
    }
  }
  for (final c in pre.children ?? const <md.Node>[]) {
    walk(c);
  }
  return buf.toString();
}
