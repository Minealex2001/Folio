import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/folio_page.dart';
import '../../../session/vault_session.dart';

/// Fase 18 de la evolución de `meeting_note` — historial de reuniones.
///
/// Sin base de datos nueva: recorre `session.pages` (mismo dato que ya usa
/// el resto de Folio — grafo, búsqueda, árbol de páginas) filtrando las que
/// tienen al menos un bloque `meeting_note`. No existe hoy una vista que
/// liste bloques por tipo a través de páginas, así que esta pantalla nueva
/// está justificada — pero no reimplementa índice ni almacenamiento.
///
/// Nota sobre "recencia": Folio no guarda un timestamp de última
/// modificación a nivel de página (ninguna feature lo tiene todavía, no es
/// una limitación introducida por meeting_note). Como proxy razonable sin
/// añadir infraestructura nueva, se usa el orden de `session.pages`
/// invertido (las páginas se añaden al final de la lista), no un
/// last-modified real.
class MeetingNotesHistoryScreen extends StatefulWidget {
  const MeetingNotesHistoryScreen({
    super.key,
    required this.session,
    required this.onOpenPage,
  });

  final VaultSession session;
  final void Function(String pageId) onOpenPage;

  @override
  State<MeetingNotesHistoryScreen> createState() =>
      _MeetingNotesHistoryScreenState();
}

class _MeetingNotesHistoryScreenState
    extends State<MeetingNotesHistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<({FolioPage page, int meetingNoteCount, String preview})> _entries() {
    final out = <({FolioPage page, int meetingNoteCount, String preview})>[];
    for (final page in widget.session.pages) {
      if (page.isTrashed) continue;
      final meetingBlocks = page.blocks.where((b) => b.type == 'meeting_note');
      if (meetingBlocks.isEmpty) continue;
      final preview = meetingBlocks
          .map((b) => b.text.trim())
          .firstWhere((t) => t.isNotEmpty, orElse: () => '');
      out.add((
        page: page,
        meetingNoteCount: meetingBlocks.length,
        preview: preview,
      ));
    }
    // Proxy de recencia documentado arriba: orden de inserción invertido.
    return out.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final entries = _entries().where((e) {
      if (query.isEmpty) return true;
      return e.page.title.toLowerCase().contains(query) ||
          e.preview.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.meetingNotesHistoryTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l10n.meetingNotesHistorySearchHint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      l10n.meetingNotesHistoryEmpty,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      return ListTile(
                        leading: const Icon(Icons.meeting_room_outlined),
                        title: Text(
                          entry.page.title.isEmpty
                              ? l10n.meetingNoteUntitledPage
                              : entry.page.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          entry.preview.isEmpty
                              ? l10n.meetingNotesHistoryNoTranscript
                              : entry.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: entry.meetingNoteCount > 1
                            ? Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('${entry.meetingNoteCount}'),
                              )
                            : null,
                        onTap: () => widget.onOpenPage(entry.page.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
