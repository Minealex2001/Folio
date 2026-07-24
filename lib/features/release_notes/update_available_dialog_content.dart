import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../app/widgets/folio_dialog.dart';
import '../../l10n/generated/app_localizations.dart';

/// Contenido del diálogo de actualización: resumen, patch notes y pregunta.
class UpdateAvailableDialogContent extends StatelessWidget {
  const UpdateAvailableDialogContent({
    super.key,
    required this.intro,
    required this.releaseNotes,
    required this.question,
  });

  final String intro;
  final String? releaseNotes;
  final String question;

  static const double dialogContentWidth = 520;

  /// Diálogo de confirmación con notas de la versión remota.
  static Future<bool?> confirm({
    required BuildContext context,
    required Widget title,
    required String intro,
    required String? releaseNotes,
    required String question,
    required String cancelLabel,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => FolioDialog(
        title: title,
        contentWidth: dialogContentWidth,
        content: UpdateAvailableDialogContent(
          intro: intro,
          releaseNotes: releaseNotes,
          question: question,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final notes = (releaseNotes ?? '').trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(intro),
        const SizedBox(height: 16),
        Text(
          l10n.updaterDialogReleaseNotesHeading,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: notes.isEmpty
                  ? Text(
                      l10n.releaseNotesEmpty,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : MarkdownBody(
                      data: notes,
                      selectable: true,
                      softLineBreak: true,
                      shrinkWrap: true,
                      extensionSet: md.ExtensionSet.gitHubFlavored,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(question),
      ],
    );
  }
}
