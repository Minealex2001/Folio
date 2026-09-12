import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../session/vault_session.dart';
import 'folio_spotify.dart';

/// Resultado del menú al pegar una URL en el editor.
enum FolioPasteUrlMode {
  markdownUrl,
  embed,
  bookmark,
  vaultMention,
  spotify,
  githubImport,
  pdfSummarize,
}

/// Fase D2 del rediseño UX del editor — detección de intención al pegar.
/// `-`→lista y `[]`→checklist ya existían (ver auditoría B1); esto añade
/// GitHub/PDF a la hoja de opciones ya existente (`showPasteUrlOptionsSheet`),
/// mismo sheet, opciones nuevas, sin UI nueva.
///
/// Alcance de v1, documentado explícitamente para no fingir más de lo que
/// hay: no existe en el repo ningún pipeline de descarga+parseo de PDF ni
/// una integración de importación real de GitHub (solo un cliente API de
/// GitHub para otro flujo, `services/github/github_api_client.dart`, sin
/// relación con pegar enlaces). "Importar"/"Guardar PDF" en v1 insertan una
/// tarjeta de marcador (mismo tipo de bloque y mecanismo de fetch de título
/// que la opción "Marcador" ya existente) — la detección de tipo es real y
/// útil por sí sola (el usuario ve una opción con nombre específico en vez
/// de un "Marcador" genérico), pero no se afirma una IA-resume-el-PDF que
/// requeriría un pipeline de contenido que no existe todavía.
bool isGithubUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host == 'github.com' || host == 'www.github.com';
}

bool isPdfUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return uri.path.toLowerCase().endsWith('.pdf');
}

Widget _pasteOptionTile({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<FolioPasteUrlMode?> showPasteUrlOptionsSheet(
  BuildContext context, {
  String? pastedUrl,
}) {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final isSpotify = folioSpotifyRefFromUrl(pastedUrl) != null;
  final isGithub = pastedUrl != null && isGithubUrl(pastedUrl);
  final isPdf = pastedUrl != null && isPdfUrl(pastedUrl);
  return showModalBottomSheet<FolioPasteUrlMode>(
    context: context,
    showDragHandle: true,
    backgroundColor: scheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  l10n.pasteUrlTitle,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isSpotify)
                _pasteOptionTile(
                  context: ctx,
                  icon: Icons.music_note_rounded,
                  title: l10n.spotifyPasteUrlOption,
                  subtitle: l10n.spotifyPasteUrlOptionSubtitle,
                  onTap: () => Navigator.pop(ctx, FolioPasteUrlMode.spotify),
                ),
              if (isGithub)
                _pasteOptionTile(
                  context: ctx,
                  icon: Icons.code_rounded,
                  title: l10n.pasteAsGithubImport,
                  subtitle: l10n.pasteAsGithubImportSubtitle,
                  onTap: () =>
                      Navigator.pop(ctx, FolioPasteUrlMode.githubImport),
                ),
              if (isPdf)
                _pasteOptionTile(
                  context: ctx,
                  icon: Icons.picture_as_pdf_rounded,
                  title: l10n.pasteAsPdfSummarize,
                  subtitle: l10n.pasteAsPdfSummarizeSubtitle,
                  onTap: () =>
                      Navigator.pop(ctx, FolioPasteUrlMode.pdfSummarize),
                ),
              _pasteOptionTile(
                context: ctx,
                icon: Icons.alternate_email_rounded,
                title: l10n.pasteAsMention,
                subtitle: l10n.pasteAsMentionSubtitleRich,
                onTap: () => Navigator.pop(ctx, FolioPasteUrlMode.vaultMention),
              ),
              _pasteOptionTile(
                context: ctx,
                icon: Icons.link_rounded,
                title: l10n.pasteAsUrl,
                subtitle: l10n.pasteAsUrlSubtitle,
                onTap: () => Navigator.pop(ctx, FolioPasteUrlMode.markdownUrl),
              ),
              _pasteOptionTile(
                context: ctx,
                icon: Icons.web_rounded,
                title: l10n.pasteAsEmbed,
                subtitle: l10n.pasteAsEmbedSubtitleWeb,
                onTap: () => Navigator.pop(ctx, FolioPasteUrlMode.embed),
              ),
              _pasteOptionTile(
                context: ctx,
                icon: Icons.bookmark_outline_rounded,
                title: l10n.pasteAsBookmark,
                subtitle: l10n.pasteAsBookmarkSubtitle,
                onTap: () => Navigator.pop(ctx, FolioPasteUrlMode.bookmark),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Selector de página para insertar mención interna `[título](folio://open/id)`.
Future<String?> showFolioPagePickerForMention(
  BuildContext context,
  VaultSession session, {
  String? excludePageId,
}) {
  final l10n = AppLocalizations.of(context);
  final pages = session.activePages;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                l10n.pickPageForMention,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: Builder(
                builder: (c) {
                  var list = pages.toList();
                  if (excludePageId != null) {
                    final filtered = list
                        .where((p) => p.id != excludePageId)
                        .toList();
                    if (filtered.isNotEmpty) list = filtered;
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final p = list[i];
                      return ListTile(
                        title: Text(
                          p.title.trim().isEmpty
                              ? l10n.untitledFallback
                              : p.title,
                        ),
                        onTap: () => Navigator.pop(ctx, p.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
