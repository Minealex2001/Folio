import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../../data/folio_internal_link.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'block_editor_support_widgets.dart';
import '../history/mermaid_markdown_builder.dart';
import 'folio_youtube.dart';

/// Escapa `<` salvo las etiquetas de subrayado permitidas (`<u>`, `</u>`).
String folioSanitizeMarkdownForPreview(String source) {
  const open = '<u>';
  const close = '</u>';
  final sb = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (_folioRegionEqualsIgnoreCase(source, i, open)) {
      sb.write(open);
      i += open.length;
    } else if (_folioRegionEqualsIgnoreCase(source, i, close)) {
      sb.write(close);
      i += close.length;
    } else if (source.codeUnitAt(i) == 0x3C /* < */ ) {
      sb.write('&lt;');
      i++;
    } else {
      sb.writeCharCode(source.codeUnitAt(i));
      i++;
    }
  }
  return sb.toString();
}

bool _folioRegionEqualsIgnoreCase(String s, int i, String asciiLower) {
  if (i + asciiLower.length > s.length) return false;
  for (var k = 0; k < asciiLower.length; k++) {
    final a = s.codeUnitAt(i + k);
    final b = asciiLower.codeUnitAt(k);
    final ca = a >= 0x41 && a <= 0x5A ? a + 32 : a;
    if (ca != b) return false;
  }
  return true;
}

MarkdownStyleSheet folioMarkdownStyleSheet(
  BuildContext context,
  TextStyle baseStyle,
  ColorScheme scheme,
) {
  final theme = Theme.of(context);
  final from = MarkdownStyleSheet.fromTheme(theme);
  final baseSize = baseStyle.fontSize ?? 15.0;
  final baseHeight = baseStyle.height ?? 1.45;

  TextStyle heading(double bump, FontWeight w) => baseStyle.copyWith(
    fontSize: baseSize + bump,
    fontWeight: w,
    height: 1.2,
    letterSpacing: w == FontWeight.w700 ? -0.3 : -0.2,
  );

  return from.copyWith(
    p: baseStyle,
    pPadding: EdgeInsets.zero,
    h1: heading(11, FontWeight.w700),
    h1Padding: const EdgeInsets.only(top: 8, bottom: 4),
    h2: heading(7, FontWeight.w700),
    h2Padding: const EdgeInsets.only(top: 6, bottom: 3),
    h3: heading(4, FontWeight.w600),
    h3Padding: const EdgeInsets.only(top: 4, bottom: 2),
    h4: heading(2, FontWeight.w600),
    h4Padding: const EdgeInsets.only(top: 2, bottom: 2),
    h5: baseStyle.copyWith(
      fontSize: baseSize + 1,
      fontWeight: FontWeight.w600,
      height: baseHeight,
    ),
    h5Padding: const EdgeInsets.only(top: 2, bottom: 1),
    h6: baseStyle.copyWith(
      fontSize: baseSize,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
      height: baseHeight,
    ),
    h6Padding: const EdgeInsets.only(top: 2, bottom: 1),
    strong: baseStyle.copyWith(fontWeight: FontWeight.w700),
    em: baseStyle.copyWith(fontStyle: FontStyle.italic),
    code: baseStyle.copyWith(
      fontFamily: 'monospace',
      fontSize: (baseStyle.fontSize ?? 14) * 0.92,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
    ),
    del: baseStyle.copyWith(
      decoration: TextDecoration.lineThrough,
      color: scheme.onSurfaceVariant,
    ),
    a: baseStyle.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
    ),
    blockquote: baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: scheme.onSurfaceVariant,
      height: baseHeight,
    ),
    blockquotePadding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.85),
          width: 3,
        ),
      ),
    ),
    listBullet: baseStyle.copyWith(height: baseHeight),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
    ),
    blockSpacing: 4,
    listIndent: 22,
  );
}

/// Vista previa Markdown acotada (GFM + HTML inline para `<u>`).
class FolioMarkdownPreview extends StatelessWidget {
  const FolioMarkdownPreview({
    super.key,
    required this.data,
    required this.styleSheet,
    this.onTapLink,
    this.onFolioPageLink,
  });

  final String data;
  final MarkdownStyleSheet styleSheet;

  /// Si es null, enlaces http(s) se abren en el navegador externo.
  final void Function(String text, String? href, String title)? onTapLink;

  /// Enlaces `folio://open/…` navegan a la página de la libreta.
  final void Function(String pageId)? onFolioPageLink;

  static Future<void> _defaultOpenExternal(String? href) async {
    if (href == null || href.isEmpty) return;
    final u = Uri.tryParse(href);
    if (u == null || !u.hasScheme) return;
    if (u.scheme != 'http' && u.scheme != 'https') return;
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    void wrappedTap(String text, String? href, String title) {
      if (onTapLink != null) {
        onTapLink!(text, href, title);
      } else {
        unawaited(_defaultOpenExternal(href));
      }
    }

    return SingleChildScrollView(
      // Evita overflows cuando el preview se renderiza dentro de una altura fija
      // y permite desplazar contenido largo (p. ej., tablas).
      physics: const ClampingScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      child: MarkdownBody(
        data: folioSanitizeMarkdownForPreview(data),
        styleSheet: styleSheet,
        shrinkWrap: true,
        fitContent: true,
        softLineBreak: true,
        selectable: false,
        extensionSet: md.ExtensionSet.gitHubFlavored,
        builders: {
          'a': _FolioMarkdownAnchorBuilder(
            onTapLink: wrappedTap,
            onFolioPageLink: onFolioPageLink,
          ),
          'pre': FolioMermaidMarkdownBuilder(),
          'blockquote': _FolioMarkdownBlockquoteBuilder(
            styleSheet: styleSheet,
            onTapLink: wrappedTap,
            onFolioPageLink: onFolioPageLink,
          ),
        },
      ),
    );
  }
}

/// Marcador para hit-testing: indica que el tap ocurrió sobre un link.
/// Se usa para que el contenedor de fila del editor no fuerce foco/edición.
const String folioLinkMetaDataTag = 'folio.link';

/// Marcador para hit-testing: indica que el tap ocurrió sobre un widget
/// interactivo (no necesariamente un link).
/// Se usa para que la fila del editor no cambie selección/foco al pulsar
/// controles embebidos (p. ej. previews).
const String folioInteractiveMetaDataTag = 'folio.interactive';

class _FolioMarkdownAnchorBuilder extends MarkdownElementBuilder {
  _FolioMarkdownAnchorBuilder({required this.onTapLink, this.onFolioPageLink});

  final void Function(String text, String? href, String title) onTapLink;
  final void Function(String pageId)? onFolioPageLink;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final href = element.attributes['href']?.trim() ?? '';
    final titleAttr = element.attributes['title'] ?? '';
    final label = element.textContent;
    final merged = preferredStyle?.merge(parentStyle) ?? parentStyle;

    final pageId = folioPageIdFromFolioUri(href);
    if (pageId != null && onFolioPageLink != null) {
      return MetaData(
        metaData: folioLinkMetaDataTag,
        behavior: HitTestBehavior.translucent,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => onFolioPageLink!(pageId),
          child: Text(
            label.isEmpty ? href : label,
            style: merged?.copyWith(decoration: TextDecoration.underline),
          ),
        ),
      );
    }

    final yt = folioYoutubeVideoIdFromUrl(href);
    if (yt != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FolioYoutubePreviewCard(
          pageUrl: href,
          videoId: yt,
          scheme: Theme.of(context).colorScheme,
          compact: true,
        ),
      );
    }

    return MetaData(
      metaData: folioLinkMetaDataTag,
      behavior: HitTestBehavior.translucent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) =>
            onTapLink(label, href.isEmpty ? null : href, titleAttr),
        child: Text(
          label.isEmpty ? href : label,
          style: merged?.copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}

class _FolioMarkdownBlockquoteBuilder extends MarkdownElementBuilder {
  _FolioMarkdownBlockquoteBuilder({
    required this.styleSheet,
    required this.onTapLink,
    this.onFolioPageLink,
  });

  final MarkdownStyleSheet styleSheet;
  final void Function(String text, String? href, String title) onTapLink;
  final void Function(String pageId)? onFolioPageLink;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final raw = _collectMarkdownText(element).trim();
    if (raw.isEmpty) return const SizedBox.shrink();
    final alert = _parseAlert(raw);
    final scheme = Theme.of(context).colorScheme;
    final child = MarkdownBody(
      data: alert?.body ?? raw,
      shrinkWrap: true,
      fitContent: true,
      selectable: false,
      softLineBreak: true,
      styleSheet: styleSheet,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      builders: {
        'a': _FolioMarkdownAnchorBuilder(
          onTapLink: onTapLink,
          onFolioPageLink: onFolioPageLink,
        ),
        'pre': FolioMermaidMarkdownBuilder(),
      },
    );
    if (alert == null) {
      return Container(
        padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.85),
              width: 3,
            ),
          ),
        ),
        child: child,
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primaryContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alert.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

String _collectMarkdownText(md.Node node) {
  final buffer = StringBuffer();
  void walk(md.Node current) {
    if (current is md.Text) {
      buffer.write(current.text);
      return;
    }
    if (current is md.Element) {
      if (current.tag == 'br') {
        buffer.write('\n');
      }
      final children = current.children ?? const <md.Node>[];
      for (final child in children) {
        walk(child);
      }
      if (current.tag == 'p' || current.tag == 'li') {
        buffer.write('\n');
      }
    }
  }

  walk(node);
  return buffer.toString().trim();
}

({String icon, String body})? _parseAlert(String raw) {
  final lines = raw.split('\n').map((line) => line.trimRight()).toList();
  if (lines.isEmpty) return null;
  final match = RegExp(
    r'^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*(.*)$',
    caseSensitive: false,
  ).firstMatch(lines.first.trim());
  if (match == null) return null;
  final kind = match.group(1)!.toUpperCase();
  final bodyLines = <String>[];
  final firstTail = match.group(2)?.trim() ?? '';
  if (firstTail.isNotEmpty) {
    bodyLines.add(firstTail);
  }
  if (lines.length > 1) {
    bodyLines.addAll(lines.skip(1));
  }
  return (
    icon: switch (kind) {
      'TIP' => '💡',
      'IMPORTANT' => '📌',
      'WARNING' => '⚠️',
      'CAUTION' => '⛔',
      _ => '📝',
    },
    body: bodyLines.join('\n').trim(),
  );
}

/// Aplica o quita un par de delimitadores alrededor de la selección (o inserta
/// ambos y deja el cursor en medio si la selección está colapsada).
bool folioToggleWrap(
  TextEditingController controller,
  String left,
  String right,
) {
  final value = controller.value;
  final text = value.text;
  var start = value.selection.start;
  var end = value.selection.end;
  if (start < 0 || end < 0) return false;
  if (start > end) {
    final t = start;
    start = end;
    end = t;
  }

  // Selección colapsada: insertar pareja y dejar cursor dentro.
  if (start == end) {
    final inserted = '$left$right';
    final newText = text.replaceRange(start, end, inserted);
    final caret = (start + left.length).clamp(0, newText.length);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
    );
    return true;
  }

  // Si la selección incluye espacios en extremos, envolver solo la parte útil
  // para evitar `** hola **` con espacios dentro.
  var innerStart = start;
  var innerEnd = end;
  while (innerStart < innerEnd && text.codeUnitAt(innerStart) == 0x20 /* ' ' */) {
    innerStart++;
  }
  while (innerEnd > innerStart &&
      text.codeUnitAt(innerEnd - 1) == 0x20 /* ' ' */) {
    innerEnd--;
  }

  // Si todo eran espacios, envolver la selección original.
  if (innerStart >= innerEnd) {
    innerStart = start;
    innerEnd = end;
  }

  if (start >= left.length &&
      end + right.length <= text.length &&
      text.substring(start - left.length, start) == left &&
      text.substring(end, end + right.length) == right) {
    final inner = text.substring(start, end);
    final newText = text.replaceRange(
      start - left.length,
      end + right.length,
      inner,
    );
    // Mantener selección sobre el texto "desenvuelto".
    final newStart = start - left.length;
    final newEnd = newStart + inner.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: newStart, extentOffset: newEnd),
    );
    return true;
  }

  if (left == '`' && right == '`') {
    final sel = text.substring(innerStart, innerEnd);
    if (sel.contains('`')) {
      return false;
    }
  }

  final inner = text.substring(innerStart, innerEnd);
  final inserted = '$left$inner$right';
  final newText = text.replaceRange(innerStart, innerEnd, inserted);
  final newSelStart = innerStart + left.length;
  final newSelEnd = newSelStart + inner.length;
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection(baseOffset: newSelStart, extentOffset: newSelEnd),
  );
  return true;
}

/// Sustituye la selección (o inserta en el cursor) por `[label](url)`.
void folioApplyLink(
  TextEditingController controller,
  String label,
  String url,
) {
  final value = controller.value;
  final text = value.text;
  var start = value.selection.start;
  var end = value.selection.end;
  if (start < 0 || end < 0) return;
  if (start > end) {
    final t = start;
    start = end;
    end = t;
  }
  final lab = label.trim().isEmpty ? url.trim() : label.trim();
  final u = url.trim();
  final md = '[$lab]($u)';
  final newText = text.replaceRange(start, end, md);
  final newOffset = start + md.length;
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newOffset),
  );
}

/// Barra compacta de formato inline (mismos marcadores que al teclear a mano).
class FolioFormatToolbar extends StatelessWidget {
  const FolioFormatToolbar({
    super.key,
    required this.controller,
    required this.colorScheme,
    required this.textFocusNode,
    this.onOpenBlockAppearance,
    this.onMentionPage,
    this.onInsertUserMention,
    this.onInsertDateMention,
    this.onInsertInlineMath,
  });

  final TextEditingController controller;
  final ColorScheme colorScheme;
  final FocusNode textFocusNode;
  final VoidCallback? onOpenBlockAppearance;

  /// Mención @página → enlace [folio://open/…].
  final Future<void> Function(BuildContext context)? onMentionPage;

  /// Inserta marcador de @usuario.
  final VoidCallback? onInsertUserMention;

  /// Inserta fecha local (recordatorio / @fecha).
  final VoidCallback? onInsertDateMention;

  /// Inserta marcadores LaTeX en línea `\\( … \\)`.
  final VoidCallback? onInsertInlineMath;

  Future<void> _link(BuildContext context) async {
    final value = controller.value;
    final text = value.text;
    var start = value.selection.start;
    var end = value.selection.end;
    if (start > end) {
      final t = start;
      start = end;
      end = t;
    }
    final defaultLabel =
        (start >= 0 && end >= 0 && start != end && end <= text.length)
        ? text.substring(start, end)
        : AppLocalizations.of(context).defaultLinkText;

    final labelCtrl = TextEditingController(text: defaultLabel);
    final urlCtrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context).linkTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).visibleTextLabel,
                ),
                autofocus:
                    defaultLabel ==
                    AppLocalizations.of(context).defaultLinkText,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).urlLabel,
                  hintText: AppLocalizations.of(context).urlHint,
                ),
                keyboardType: TextInputType.url,
                autofocus:
                    defaultLabel !=
                    AppLocalizations.of(context).defaultLinkText,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context).insert),
            ),
          ],
        ),
      );
      if (ok == true && context.mounted) {
        final u = urlCtrl.text.trim();
        if (u.isEmpty) return;
        final lab = labelCtrl.text.trim();
        folioApplyLink(controller, lab, u);
        textFocusNode.requestFocus();
      }
    } finally {
      labelCtrl.dispose();
      urlCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    void applyFormat(void Function() op) {
      op();
      textFocusNode.requestFocus();
    }

    final iconColor = colorScheme.onSurfaceVariant;
    Widget btn({
      required IconData icon,
      required String tip,
      required VoidCallback onPressed,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: IconButton(
          style: IconButton.styleFrom(
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: Icon(icon, size: 20, color: iconColor),
          onPressed: onPressed,
          tooltip: tip,
        ),
      );
    }

    return Semantics(
      container: true,
      label: AppLocalizations.of(context).formatToolbar,
      child: BlockEditorFloatingPanel(
        scheme: colorScheme,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onOpenBlockAppearance != null)
                    btn(
                      icon: Icons.palette_outlined,
                      tip: 'Apariencia del bloque',
                      onPressed: () => applyFormat(onOpenBlockAppearance!),
                    ),
                  btn(
                    icon: Icons.format_bold_rounded,
                    tip: AppLocalizations.of(context).boldTip,
                    onPressed: () => applyFormat(
                      () => folioToggleWrap(controller, '**', '**'),
                    ),
                  ),
                  btn(
                    icon: Icons.format_italic_rounded,
                    tip: AppLocalizations.of(context).italicTip,
                    onPressed: () => applyFormat(
                      () => folioToggleWrap(controller, '_', '_'),
                    ),
                  ),
                  btn(
                    icon: Icons.format_underlined_rounded,
                    tip: AppLocalizations.of(context).underlineTip,
                    onPressed: () => applyFormat(
                      () => folioToggleWrap(controller, '<u>', '</u>'),
                    ),
                  ),
                  btn(
                    icon: Icons.code_rounded,
                    tip: AppLocalizations.of(context).inlineCodeTip,
                    onPressed: () => applyFormat(
                      () => folioToggleWrap(controller, '`', '`'),
                    ),
                  ),
                  btn(
                    icon: Icons.strikethrough_s_rounded,
                    tip: AppLocalizations.of(context).strikeTip,
                    onPressed: () => applyFormat(
                      () => folioToggleWrap(controller, '~~', '~~'),
                    ),
                  ),
                  btn(
                    icon: Icons.link_rounded,
                    tip: AppLocalizations.of(context).linkTip,
                    onPressed: () => _link(context),
                  ),
                  if (onMentionPage != null)
                    btn(
                      icon: Icons.insert_link_outlined,
                      tip: 'Mencionar página (@página)',
                      onPressed: () async {
                        await onMentionPage!(context);
                        textFocusNode.requestFocus();
                      },
                    ),
                  if (onInsertUserMention != null)
                    btn(
                      icon: Icons.alternate_email_rounded,
                      tip: '@usuario',
                      onPressed: () => applyFormat(onInsertUserMention!),
                    ),
                  if (onInsertDateMention != null)
                    btn(
                      icon: Icons.event_rounded,
                      tip: '@fecha',
                      onPressed: () => applyFormat(onInsertDateMention!),
                    ),
                  if (onInsertInlineMath != null)
                    btn(
                      icon: Icons.functions_rounded,
                      tip: 'Matemáticas en línea \\( \\)',
                      onPressed: () => applyFormat(onInsertInlineMath!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
