import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_quill/flutter_quill.dart' as quill;
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

  // Si el usuario selecciona incluyendo los delimitadores (p. ej. selecciona
  // `**hola**` entero), quitar los delimitadores exteriores en vez de anidar.
  // Para inline code, dejamos que el guard anterior decida (no tocar selecciones
  // que contienen backticks).
  final selected = text.substring(start, end);
  if (selected.length >= left.length + right.length &&
      selected.startsWith(left) &&
      selected.endsWith(right)) {
    final inner = selected.substring(left.length, selected.length - right.length);
    final newText = text.replaceRange(start, end, inner);
    final newEnd = (start + inner.length).clamp(0, newText.length);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: start, extentOffset: newEnd),
    );
    return true;
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

/// Fila de herramientas horizontal con flechas cuando el contenido supera el ancho disponible.
class _FolioToolbarScrollStrip extends StatefulWidget {
  const _FolioToolbarScrollStrip({
    required this.colorScheme,
    required this.child,
    this.editorFocusNode,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  final ColorScheme colorScheme;
  final Widget child;

  /// Foco del editor (Quill/TextField): se reclama en pointerDown para que la barra no desaparezca.
  final FocusNode? editorFocusNode;

  /// Igual que en el resto de botones de la barra — mantiene visible el panel mientras se pulsa.
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  @override
  State<_FolioToolbarScrollStrip> createState() => _FolioToolbarScrollStripState();
}

class _FolioToolbarScrollStripState extends State<_FolioToolbarScrollStrip> {
  final ScrollController _controller = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncArrowState);
    // Dos frames: el scroll position a veces no está listo en el primero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncArrowState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncArrowState();
      });
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_syncArrowState);
    _controller.dispose();
    super.dispose();
  }

  void _syncArrowState() {
    if (!mounted) return;
    final c = _controller;
    if (!c.hasClients) {
      if (_canScrollLeft || _canScrollRight) {
        setState(() {
          _canScrollLeft = false;
          _canScrollRight = false;
        });
      }
      return;
    }
    final p = c.position;
    final left = c.offset > 0.5;
    final right = c.offset < p.maxScrollExtent - 0.5;
    if (left != _canScrollLeft || right != _canScrollRight) {
      setState(() {
        _canScrollLeft = left;
        _canScrollRight = right;
      });
    }
  }

  void _deferSyncArrowState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncArrowState();
    });
  }

  /// Después del frame para que [InkWell.onTap] se ejecute antes de limpiar
  /// `_toolbarInteractionBlockId` en el padre (si no, la barra se desmonta y el scroll no aplica).
  void _scheduleInteractionEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onInteractionEnd?.call();
    });
  }

  void _tryScrollStep(double direction) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final maxExt = p.maxScrollExtent;
    if (maxExt <= 0) return;
    final extent = p.viewportDimension;
    final delta = direction * extent * 0.72;
    final target = (_controller.offset + delta).clamp(0.0, maxExt);
    if ((target - _controller.offset).abs() < 0.5) return;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _scrollArrowButton({
    required IconData icon,
    required String tooltip,
    required double direction,
  }) {
    final enabled = direction < 0 ? _canScrollLeft : _canScrollRight;
    final iconColor = widget.colorScheme.onSurfaceVariant;
    final faded = iconColor.withValues(alpha: 0.38);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        widget.onInteractionStart?.call();
        final n = widget.editorFocusNode;
        if (n != null && n.canRequestFocus) {
          n.requestFocus();
        }
      },
      onPointerUp: (_) => _scheduleInteractionEnd(),
      onPointerCancel: (_) => _scheduleInteractionEnd(),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(8),
          // Siempre intentar scroll: los flags pueden ir un frame retrasados.
          onTap: () => _tryScrollStep(direction),
          child: SizedBox(
            width: 36,
            height: 40,
            child: Center(
              child: Icon(
                icon,
                size: 22,
                color: enabled ? iconColor : faded,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _deferSyncArrowState();
        return false;
      },
      child: Row(
        children: [
          _scrollArrowButton(
            icon: Icons.chevron_left_rounded,
            tooltip: l10n.formatToolbarScrollPrevious,
            direction: -1,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              primary: false,
              child: widget.child,
            ),
          ),
          _scrollArrowButton(
            icon: Icons.chevron_right_rounded,
            tooltip: l10n.formatToolbarScrollNext,
            direction: 1,
          ),
        ],
      ),
    );
  }
}

/// Barra compacta de formato inline (mismos marcadores que al teclear a mano).
class FolioFormatToolbar extends StatefulWidget {
  const FolioFormatToolbar({
    super.key,
    required this.controller,
    required this.colorScheme,
    required this.textFocusNode,
    this.onInteractionStart,
    this.onInteractionEnd,
    this.onOpenBlockAppearance,
    this.onMentionPage,
    this.onInsertUserMention,
    this.onInsertDateMention,
    this.onInsertInlineMath,
    this.onAskQuill,
  });

  final TextEditingController controller;
  final ColorScheme colorScheme;
  final FocusNode textFocusNode;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;
  final VoidCallback? onOpenBlockAppearance;

  /// Mención @página → enlace [folio://open/…].
  final Future<void> Function(BuildContext context)? onMentionPage;

  /// Inserta marcador de @usuario.
  final VoidCallback? onInsertUserMention;

  /// Inserta fecha local (recordatorio / @fecha).
  final VoidCallback? onInsertDateMention;

  /// Inserta marcadores LaTeX en línea `\\( … \\)`.
  final VoidCallback? onInsertInlineMath;

  /// Pregunta a Quill sobre la selección (panel de chat).
  final VoidCallback? onAskQuill;

  @override
  State<FolioFormatToolbar> createState() => _FolioFormatToolbarState();
}

/// Toolbar para `flutter_quill` (WYSIWYG).
class FolioQuillFormatToolbar extends StatelessWidget {
  const FolioQuillFormatToolbar({
    super.key,
    required this.controller,
    required this.colorScheme,
    required this.focusNode,
    this.onInteractionStart,
    this.onInteractionEnd,
    this.onAskQuill,
  });

  final quill.QuillController controller;
  final ColorScheme colorScheme;
  final FocusNode focusNode;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;
  final VoidCallback? onAskQuill;

  void _toggle(quill.Attribute attr) {
    final current = controller.getSelectionStyle().attributes[attr.key];
    controller.formatSelection(current == null ? attr : quill.Attribute.clone(attr, null));
  }

  void _setBlockAttr(quill.Attribute attr) {
    final current = controller.getSelectionStyle().attributes[attr.key];
    controller.formatSelection(current == null ? attr : quill.Attribute.clone(attr, null));
  }

  void _setList(quill.Attribute<String?> listAttr) {
    final current = controller.getSelectionStyle().attributes[quill.Attribute.list.key];
    final curVal = current?.value;
    controller.formatSelection(curVal == listAttr.value ? quill.Attribute.clone(listAttr, null) : listAttr);
  }

  void _indent(bool increase) {
    if (increase) {
      controller.indentSelection(true);
    } else {
      controller.indentSelection(false);
    }
  }

  void _clearInline() {
    final attrs = controller.getSelectionStyle().attributes;
    for (final key in attrs.keys.toList()) {
      // No tocar atributos de bloque aquí.
      if (quill.Attribute.blockKeys.contains(key)) continue;
      controller.formatSelection(quill.Attribute.fromKeyValue(key, null));
    }
  }

  Future<void> _link(BuildContext context) async {
    final sel = controller.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final current = controller.getSelectionStyle().attributes[quill.Attribute.link.key]?.value;
    final urlCtrl = TextEditingController(text: current is String ? current : '');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context).linkTitle),
          content: TextField(
            controller: urlCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).urlLabel,
              hintText: AppLocalizations.of(context).urlHint,
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
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
        final url = urlCtrl.text.trim();
        if (url.isEmpty) return;
        controller.formatSelection(quill.LinkAttribute(url));
      }
    } finally {
      urlCtrl.dispose();
    }
  }

  void _unlink() {
    controller.formatSelection(quill.LinkAttribute(null));
  }

  Future<void> _pickColor(
    BuildContext context, {
    required bool background,
  }) async {
    final attr = background ? quill.Attribute.background : quill.Attribute.color;

    Color parseCurrent() {
      final current =
          controller.getSelectionStyle().attributes[attr.key]?.value as String?;
      if (current == null || current.trim().isEmpty) {
        return const Color(0xFF000000);
      }
      final s = current.trim();
      final hex = s.startsWith('#') ? s.substring(1) : s;
      if (hex.length != 6) return const Color(0xFF000000);
      final v = int.tryParse(hex, radix: 16);
      if (v == null) return const Color(0xFF000000);
      return Color(0xFF000000 | v);
    }

    String toHex(Color c) {
      final rgb = c.value & 0x00FFFFFF;
      return '#${rgb.toRadixString(16).padLeft(6, '0')}';
    }

    Color temp = parseCurrent();
    Future<Color?> showAnchoredPicker() async {
      final buttonBox = context.findRenderObject() as RenderBox?;
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      if (buttonBox == null || overlay == null) return null;
      final buttonRect = buttonBox.localToGlobal(Offset.zero, ancestor: overlay) &
          buttonBox.size;
      final position = RelativeRect.fromRect(
        buttonRect,
        Offset.zero & overlay.size,
      );

      final scheme = Theme.of(context).colorScheme;
      final maxW = math.min(360.0, overlay.size.width - 24.0);
      final pickerW = maxW.clamp(280.0, 360.0);

      return await showMenu<Color?>(
        context: context,
        position: position,
        constraints: BoxConstraints.tightFor(width: pickerW),
        items: [
          PopupMenuItem<Color?>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: StatefulBuilder(
              builder: (menuCtx, setMenuState) => Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            background ? 'Color de fondo' : 'Color de texto',
                            style: Theme.of(menuCtx).textTheme.titleSmall,
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: temp,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ColorPicker(
                      pickerColor: temp,
                      onColorChanged: (c) => setMenuState(() => temp = c),
                      enableAlpha: false,
                      portraitOnly: true,
                      colorPickerWidth: pickerW - 24,
                      labelTypes: const [],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            toHex(temp).toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(menuCtx).textTheme.labelLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(menuCtx, null),
                          child: Text(AppLocalizations.of(menuCtx).cancel),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(menuCtx, const Color(0x00000000)),
                          child: const Text('Quitar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(menuCtx, temp),
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final picked = await showAnchoredPicker();
    if (picked == null) return;
    if (picked.value == 0x00000000) {
      controller.formatSelection(quill.Attribute.clone(attr, null));
      return;
    }
    controller.formatSelection(quill.Attribute.clone(attr, toHex(picked)));
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = colorScheme.onSurfaceVariant;
    Widget btn({
      required IconData icon,
      required String tip,
      required VoidCallback onActivate,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            onInteractionStart?.call();
            if (!focusNode.hasFocus) {
              focusNode.requestFocus();
            }
            onActivate();
          },
          onPointerUp: (_) => onInteractionEnd?.call(),
          onPointerCancel: (_) => onInteractionEnd?.call(),
          child: Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(icon, size: 20, color: iconColor),
              onPressed: null, // activamos en pointerDown (desktop-safe)
              tooltip: tip,
            ),
          ),
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
            child: _FolioToolbarScrollStrip(
              colorScheme: colorScheme,
              editorFocusNode: focusNode,
              onInteractionStart: onInteractionStart,
              onInteractionEnd: onInteractionEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  btn(
                    icon: Icons.undo_rounded,
                    tip: AppLocalizations.of(context).canvasToolbarUndo,
                    onActivate: () => controller.undo(),
                  ),
                  btn(
                    icon: Icons.redo_rounded,
                    tip: AppLocalizations.of(context).canvasToolbarRedo,
                    onActivate: () => controller.redo(),
                  ),
                  btn(
                    icon: Icons.format_bold_rounded,
                    tip: AppLocalizations.of(context).boldTip,
                    onActivate: () => _toggle(quill.Attribute.bold),
                  ),
                  btn(
                    icon: Icons.format_italic_rounded,
                    tip: AppLocalizations.of(context).italicTip,
                    onActivate: () => _toggle(quill.Attribute.italic),
                  ),
                  btn(
                    icon: Icons.format_underlined_rounded,
                    tip: AppLocalizations.of(context).underlineTip,
                    onActivate: () => _toggle(quill.Attribute.underline),
                  ),
                  btn(
                    icon: Icons.strikethrough_s_rounded,
                    tip: AppLocalizations.of(context).strikeTip,
                    onActivate: () => _toggle(quill.Attribute.strikeThrough),
                  ),
                  btn(
                    icon: Icons.code_rounded,
                    tip: AppLocalizations.of(context).inlineCodeTip,
                    onActivate: () => _toggle(quill.Attribute.inlineCode),
                  ),
                  btn(
                    icon: Icons.link_rounded,
                    tip: AppLocalizations.of(context).linkTip,
                    onActivate: () => unawaited(_link(context)),
                  ),
                  btn(
                    icon: Icons.link_off_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillUnlink,
                    onActivate: _unlink,
                  ),
                  btn(
                    icon: Icons.format_color_text_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillTextColor,
                    onActivate: () => unawaited(
                      _pickColor(context, background: false),
                    ),
                  ),
                  btn(
                    icon: Icons.format_color_fill_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillFillColor,
                    onActivate: () => unawaited(
                      _pickColor(context, background: true),
                    ),
                  ),
                  btn(
                    icon: Icons.highlight_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillHighlight,
                    onActivate: () => controller.formatSelection(
                      quill.Attribute.clone(
                        quill.Attribute.background,
                        '#fff59d',
                      ),
                    ),
                  ),
                  btn(
                    icon: Icons.title_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillHeading1,
                    onActivate: () =>
                        _setBlockAttr(const quill.HeaderAttribute(level: 1)),
                  ),
                  btn(
                    icon: Icons.title_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillHeading2,
                    onActivate: () =>
                        _setBlockAttr(const quill.HeaderAttribute(level: 2)),
                  ),
                  btn(
                    icon: Icons.title_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillHeading3,
                    onActivate: () =>
                        _setBlockAttr(const quill.HeaderAttribute(level: 3)),
                  ),
                  btn(
                    icon: Icons.format_list_bulleted_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillBulletList,
                    onActivate: () => _setList(quill.Attribute.ul),
                  ),
                  btn(
                    icon: Icons.format_list_numbered_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillNumberedList,
                    onActivate: () => _setList(quill.Attribute.ol),
                  ),
                  btn(
                    icon: Icons.checklist_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillChecklist,
                    onActivate: () => _setList(quill.Attribute.unchecked),
                  ),
                  btn(
                    icon: Icons.format_quote_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillQuote,
                    onActivate: () => _setBlockAttr(quill.Attribute.blockQuote),
                  ),
                  btn(
                    icon: Icons.format_indent_increase_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillIndentMore,
                    onActivate: () => _indent(true),
                  ),
                  btn(
                    icon: Icons.format_indent_decrease_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillIndentLess,
                    onActivate: () => _indent(false),
                  ),
                  btn(
                    icon: Icons.format_clear_rounded,
                    tip: AppLocalizations.of(context).formatToolbarQuillClear,
                    onActivate: _clearInline,
                  ),
                  if (onAskQuill != null)
                    btn(
                      icon: Icons.smart_toy_outlined,
                      tip: AppLocalizations.of(context).blockEditorAskQuillTooltip,
                      onActivate: onAskQuill!,
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

class _FolioFormatToolbarState extends State<FolioFormatToolbar> {
  TextSelection? _lastSelection;
  bool _skipNextPressed = false;

  VoidCallback? _controllerListener;

  @override
  void initState() {
    super.initState();
    _attachControllerListener(widget.controller);
  }

  @override
  void didUpdateWidget(covariant FolioFormatToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachControllerListener(oldWidget.controller);
      _attachControllerListener(widget.controller);
    }
  }

  @override
  void dispose() {
    _detachControllerListener(widget.controller);
    super.dispose();
  }

  void _attachControllerListener(TextEditingController c) {
    void listener() {
      final sel = c.selection;
      if (!sel.isValid) return;
      _lastSelection = sel;
    }

    _controllerListener = listener;
    c.addListener(listener);
    // Captura inicial por si el caller ya tiene selección.
    listener();
  }

  void _detachControllerListener(TextEditingController c) {
    final l = _controllerListener;
    if (l == null) return;
    c.removeListener(l);
    _controllerListener = null;
  }

  void _captureSelection() {
    final sel = widget.controller.selection;
    if (!sel.isValid) return;
    _lastSelection = sel;
  }

  void _restoreSelectionIfPossible() {
    final sel = _lastSelection;
    if (sel == null || !sel.isValid) return;
    final len = widget.controller.text.length;
    if (len == 0) return;
    final base = sel.baseOffset.clamp(0, len);
    final extent = sel.extentOffset.clamp(0, len);
    widget.controller.selection = TextSelection(
      baseOffset: base,
      extentOffset: extent,
    );
  }

  void _selectAllIfCollapsedOrInvalid() {
    final sel = widget.controller.selection;
    final len = widget.controller.text.length;
    if (len == 0) return;
    if (!sel.isValid || sel.isCollapsed) {
      widget.controller.selection = TextSelection(baseOffset: 0, extentOffset: len);
    }
  }

  void _applyInlineFormat(bool Function() op, {bool wrapWholeBlockWhenNoSelection = true}) {
    _restoreSelectionIfPossible();
    if (wrapWholeBlockWhenNoSelection) {
      _selectAllIfCollapsedOrInvalid();
    }
    op();
    widget.textFocusNode.requestFocus();
  }

  Future<void> _link(BuildContext context) async {
    final value = widget.controller.value;
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
        _restoreSelectionIfPossible();
        folioApplyLink(widget.controller, lab, u);
        widget.textFocusNode.requestFocus();
      }
    } finally {
      labelCtrl.dispose();
      urlCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.colorScheme.onSurfaceVariant;
    Widget btn({
      required IconData icon,
      required String tip,
      required VoidCallback onPressed,
      bool activateOnPointerDown = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            _captureSelection();
            widget.onInteractionStart?.call();
            // En desktop, el foco puede cambiar en pointerDown y hacer que la
            // toolbar se desmonte antes del "tap" (por lo tanto, sin onPressed).
            // Reclamamos el foco del TextField inmediatamente.
            widget.textFocusNode.requestFocus();
            if (activateOnPointerDown) {
              _skipNextPressed = true;
              onPressed();
            }
          },
          onPointerUp: (_) => widget.onInteractionEnd?.call(),
          onPointerCancel: (_) => widget.onInteractionEnd?.call(),
          child: Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(icon, size: 20, color: iconColor),
              onPressed: () {
                if (activateOnPointerDown && _skipNextPressed) {
                  _skipNextPressed = false;
                  return;
                }
                onPressed();
              },
              tooltip: tip,
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: AppLocalizations.of(context).formatToolbar,
      child: FocusScope(
        canRequestFocus: false,
        child: BlockEditorFloatingPanel(
          scheme: widget.colorScheme,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: _FolioToolbarScrollStrip(
                colorScheme: widget.colorScheme,
                editorFocusNode: widget.textFocusNode,
                onInteractionStart: widget.onInteractionStart,
                onInteractionEnd: widget.onInteractionEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onOpenBlockAppearance != null)
                      btn(
                        icon: Icons.palette_outlined,
                        tip: 'Apariencia del bloque',
                        onPressed: () => _applyInlineFormat(() {
                          widget.onOpenBlockAppearance!.call();
                          return true;
                        }),
                      ),
                    btn(
                      icon: Icons.format_bold_rounded,
                      tip: AppLocalizations.of(context).boldTip,
                      onPressed: () => _applyInlineFormat(
                        () => folioToggleWrap(widget.controller, '**', '**'),
                      ),
                      activateOnPointerDown: true,
                    ),
                    btn(
                      icon: Icons.format_italic_rounded,
                      tip: AppLocalizations.of(context).italicTip,
                      onPressed: () => _applyInlineFormat(
                        () => folioToggleWrap(widget.controller, '_', '_'),
                      ),
                      activateOnPointerDown: true,
                    ),
                    btn(
                      icon: Icons.format_underlined_rounded,
                      tip: AppLocalizations.of(context).underlineTip,
                      onPressed: () => _applyInlineFormat(
                        () => folioToggleWrap(widget.controller, '<u>', '</u>'),
                      ),
                      activateOnPointerDown: true,
                    ),
                    btn(
                      icon: Icons.code_rounded,
                      tip: AppLocalizations.of(context).inlineCodeTip,
                      onPressed: () => _applyInlineFormat(
                        () => folioToggleWrap(widget.controller, '`', '`'),
                        wrapWholeBlockWhenNoSelection: false,
                      ),
                      activateOnPointerDown: true,
                    ),
                    btn(
                      icon: Icons.strikethrough_s_rounded,
                      tip: AppLocalizations.of(context).strikeTip,
                      onPressed: () => _applyInlineFormat(
                        () => folioToggleWrap(widget.controller, '~~', '~~'),
                      ),
                      activateOnPointerDown: true,
                    ),
                    btn(
                      icon: Icons.link_rounded,
                      tip: AppLocalizations.of(context).linkTip,
                      onPressed: () {
                        _restoreSelectionIfPossible();
                        unawaited(_link(context));
                      },
                    ),
                    if (widget.onMentionPage != null)
                      btn(
                        icon: Icons.insert_link_outlined,
                        tip: 'Mencionar página (@página)',
                        onPressed: () async {
                          _restoreSelectionIfPossible();
                          await widget.onMentionPage!(context);
                          widget.textFocusNode.requestFocus();
                        },
                      ),
                    if (widget.onInsertUserMention != null)
                      btn(
                        icon: Icons.alternate_email_rounded,
                        tip: '@usuario',
                        onPressed: () => _applyInlineFormat(() {
                          widget.onInsertUserMention!.call();
                          return true;
                        }),
                      ),
                    if (widget.onInsertDateMention != null)
                      btn(
                        icon: Icons.event_rounded,
                        tip: '@fecha',
                        onPressed: () => _applyInlineFormat(() {
                          widget.onInsertDateMention!.call();
                          return true;
                        }),
                      ),
                    if (widget.onInsertInlineMath != null)
                      btn(
                        icon: Icons.functions_rounded,
                        tip: 'Matemáticas en línea \\( \\)',
                        onPressed: () => _applyInlineFormat(() {
                          widget.onInsertInlineMath!.call();
                          return true;
                        }),
                      ),
                    if (widget.onAskQuill != null)
                      btn(
                        icon: Icons.smart_toy_outlined,
                        tip: AppLocalizations.of(context).blockEditorAskQuillTooltip,
                        onPressed: () {
                          _restoreSelectionIfPossible();
                          widget.onAskQuill!.call();
                          widget.textFocusNode.requestFocus();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
