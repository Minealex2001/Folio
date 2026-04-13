import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

class ReleaseNotesPage extends StatelessWidget {
  const ReleaseNotesPage({
    super.key,
    required this.versionLabel,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.publishedAt,
    required this.tagName,
  });

  final String versionLabel;
  final String? releaseTitle;
  final String releaseNotes;
  final DateTime? publishedAt;
  final String? tagName;

  @override
  Widget build(BuildContext context) {
    final isEs = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('es');
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final normalizedNotes = releaseNotes.trim();
    final details = <String>[
      if (versionLabel.trim().isNotEmpty) versionLabel.trim(),
      if ((tagName ?? '').trim().isNotEmpty) (tagName ?? '').trim(),
      if (publishedAt != null) _formatDate(publishedAt!, isEs),
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(title: Text(isEs ? 'Notas de version' : 'Release notes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              if ((releaseTitle ?? '').trim().isNotEmpty)
                Text(
                  releaseTitle!.trim(),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  details,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: normalizedNotes.isEmpty
                    ? Text(
                        isEs
                            ? 'No hay notas de version disponibles para esta version.'
                            : 'No release notes are available for this version.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : MarkdownBody(
                        data: normalizedNotes,
                        selectable: true,
                        softLineBreak: true,
                        shrinkWrap: true,
                        extensionSet: md.ExtensionSet.gitHubFlavored,
                      ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(isEs ? 'Continuar' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date, bool isEs) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return isEs ? '$d/$m/$y' : '$y-$m-$d';
  }
}
