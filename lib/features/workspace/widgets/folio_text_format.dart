import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../l10n/generated/app_localizations.dart';

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
  return from.copyWith(
    p: baseStyle,
    pPadding: EdgeInsets.zero,
    h1: baseStyle,
    h1Padding: EdgeInsets.zero,
    h2: baseStyle,
    h2Padding: EdgeInsets.zero,
    h3: baseStyle,
    h3Padding: EdgeInsets.zero,
    h4: baseStyle,
    h4Padding: EdgeInsets.zero,
    h5: baseStyle,
    h5Padding: EdgeInsets.zero,
    h6: baseStyle,
    h6Padding: EdgeInsets.zero,
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
    blockSpacing: 0,
    listIndent: 20,
    blockquotePadding: const EdgeInsets.only(left: 8),
  );
}

/// Vista previa Markdown acotada (GFM + HTML inline para `<u>`).
class FolioMarkdownPreview extends StatelessWidget {
  const FolioMarkdownPreview({
    super.key,
    required this.data,
    required this.styleSheet,
  });

  final String data;
  final MarkdownStyleSheet styleSheet;

  @override
  Widget build(BuildContext context) {
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
        selectable: false,
        extensionSet: md.ExtensionSet.gitHubFlavored,
      ),
    );
  }
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
    final newOffset = start - left.length + inner.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    return true;
  }

  if (left == '`' && right == '`') {
    final sel = text.substring(start, end);
    if (sel.contains('`')) {
      return false;
    }
  }

  final inner = text.substring(start, end);
  final inserted = '$left$inner$right';
  final newText = text.replaceRange(start, end, inserted);
  final newOffset = start + inserted.length;
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newOffset),
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
  });

  final TextEditingController controller;
  final ColorScheme colorScheme;
  final FocusNode textFocusNode;

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
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: Material(
          elevation: 0,
          color: colorScheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
