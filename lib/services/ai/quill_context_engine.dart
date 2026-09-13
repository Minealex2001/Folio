// Fase 1 de Quill 2.0 — punto único de ensamblado de contexto para el chat
// principal de Quill. Antes de este archivo, la lógica vivía repartida entre
// `workspace_page_ai_chat.dart` (_composeAiExtraContextForNextSend, memoria +
// selección + última reunión) y `vault_session_ai.dart`
// (_resolveAiChatContextPageIds/_buildAiChatPagesTextContext, páginas de
// referencia). Este motor centraliza ambas piezas como una sola fuente de
// verdad, sin depender de Flutter/widgets ni de ningún proveedor de IA, para
// poder testearlo de forma aislada y reutilizarlo desde cualquier punto de
// llamada sin duplicar la lógica.
//
// Deliberadamente NO toca: `_maybeBuildAppDocsContext` (docs grounding),
// el camino de contexto de `ai_selection_popover_host.dart`, ni la
// construcción del systemPrompt en sí (`_buildAgentCompletionRequest`).

import '../../models/folio_page.dart';
import '../../models/vault_memory_fact.dart';

enum QuillContextSourceKind {
  activePage,
  referencePage,
  memoryFacts,
  selection,
  lastMeeting,
}

class QuillContextSource {
  const QuillContextSource({
    required this.kind,
    required this.label,
    required this.content,
  });

  final QuillContextSourceKind kind;
  final String label;
  final String content;
}

class QuillContextResult {
  const QuillContextResult(this.sources, this.combinedText);

  final List<QuillContextSource> sources;

  /// Texto ya formateado, calculado por cada método de ensamblado con el
  /// formato exacto que el código original producía para ese caso — el
  /// espaciado entre páginas de referencia y entre bloques de contexto
  /// "extra" nunca fue el mismo, así que no se generaliza en un único
  /// formateador genérico (rompería el requisito de no cambiar el texto
  /// enviado hoy al modelo).
  final String combinedText;

  int get sourceCount => sources.length;
}

/// Ensambla el contexto que Quill adjunta a cada envío del chat principal:
/// páginas de referencia (Fase 1a) y contexto "extra" (memoria/selección/
/// última reunión, Fase 1b). Sin estado propio — instanciable libremente.
class QuillContextEngine {
  const QuillContextEngine();

  /// Reemplaza la lógica de `_composeAiExtraContextForNextSend` en
  /// `workspace_page_ai_chat.dart`. Mismo orden que antes: memoria → selección
  /// → última reunión. Los headers se reciben ya traducidos porque el motor
  /// no conoce l10n.
  QuillContextResult assembleExtraContext({
    required List<VaultMemoryFact> memoryFacts,
    required String memoryFactsHeader,
    String? selectionSnippet,
    required String selectionHeader,
    String? lastMeetingSnippet,
    required String lastMeetingHeader,
  }) {
    final sources = <QuillContextSource>[];
    final text = StringBuffer();

    if (memoryFacts.isNotEmpty) {
      final body = StringBuffer();
      for (final fact in memoryFacts) {
        body.writeln('- ${fact.text.trim()}');
      }
      final content = body.toString().trim();
      sources.add(
        QuillContextSource(
          kind: QuillContextSourceKind.memoryFacts,
          label: memoryFactsHeader,
          content: content,
        ),
      );
      text.writeln(memoryFactsHeader);
      for (final fact in memoryFacts) {
        text.writeln('- ${fact.text.trim()}');
      }
    }

    final selection = selectionSnippet?.trim() ?? '';
    if (selection.isNotEmpty) {
      sources.add(
        QuillContextSource(
          kind: QuillContextSourceKind.selection,
          label: selectionHeader,
          content: selection,
        ),
      );
      text.writeln(selectionHeader);
      text.writeln(selection);
    }

    final lastMeeting = lastMeetingSnippet?.trim() ?? '';
    if (lastMeeting.isNotEmpty) {
      sources.add(
        QuillContextSource(
          kind: QuillContextSourceKind.lastMeeting,
          label: lastMeetingHeader,
          content: lastMeeting,
        ),
      );
      text.writeln(lastMeetingHeader);
      text.writeln(lastMeeting);
    }

    return QuillContextResult(sources, text.toString().trim());
  }

  /// Reemplaza `_resolveAiChatContextPageIds` en `vault_session_ai.dart`
  /// exactamente (incluida su firma como lista de ids): `contextPageIds`
  /// tiene prioridad sobre `scopePageId`. Único cambio de comportamiento
  /// deliberado: excluye páginas en papelera (`page.isTrashed`), algo que el
  /// código original no hacía porque `VaultSession._pageById` no mira
  /// `trashedAt` — ver la fase del plan para el porqué.
  List<String> resolveContextPageIds({
    required bool includePageContext,
    required List<String> contextPageIds,
    String? scopePageId,
    required FolioPage? Function(String id) pageById,
  }) {
    if (!includePageContext) return const [];
    final seen = <String>{};
    final out = <String>[];
    void add(String id) {
      final page = pageById(id);
      if (page == null || page.isTrashed) return;
      if (seen.add(id)) out.add(id);
    }

    if (contextPageIds.isNotEmpty) {
      for (final id in contextPageIds) {
        add(id);
      }
      return out;
    }
    if (scopePageId != null) add(scopePageId);
    return out;
  }

  /// Reemplaza `_buildAiChatPagesTextContext` en `vault_session_ai.dart`
  /// exactamente: mismo límite (3 páginas / 6000 chars por página / 14000
  /// chars totales), mismo texto de fallback cuando no hay páginas, mismo
  /// formato `[ACTIVE_PAGE]`/`[REFERENCE_PAGE N]` con línea en blanco entre
  /// páginas. `pageIds` ya debe venir resuelto (p. ej. por
  /// `resolveContextPageIds`).
  QuillContextResult buildPagesTextContext(
    List<String> pageIds, {
    required bool isEs,
    String? activePageId,
    required FolioPage? Function(String id) pageById,
  }) {
    if (pageIds.isEmpty) {
      final fallback = isEs
          ? '(No hay folios de texto en el contexto.)'
          : '(No pages in the text context.)';
      return QuillContextResult(const [], fallback);
    }

    const maxPages = 3;
    const maxCharsPerPage = 6000;
    const maxTotalChars = 14000;

    final sources = <QuillContextSource>[];
    final text = StringBuffer();
    var refIndex = 0;
    final limitedPageIds = pageIds.length <= maxPages
        ? pageIds
        : pageIds.sublist(0, maxPages);

    for (var i = 0; i < limitedPageIds.length; i++) {
      if (text.length >= maxTotalChars) break;
      final page = pageById(limitedPageIds[i]);
      if (page == null) continue;
      if (text.isNotEmpty) text.writeln();

      final isActive = activePageId != null && page.id == activePageId;
      final label = isActive
          ? '[ACTIVE_PAGE] ${page.title}'
          : '[REFERENCE_PAGE ${++refIndex}] ${page.title}';
      final content = page.plainTextContent;
      final truncated = content.length <= maxCharsPerPage
          ? content
          : '${content.substring(0, maxCharsPerPage)}\n…';

      text.writeln(label);
      text.writeln(truncated);
      sources.add(
        QuillContextSource(
          kind: isActive
              ? QuillContextSourceKind.activePage
              : QuillContextSourceKind.referencePage,
          label: label,
          content: truncated,
        ),
      );
    }

    return QuillContextResult(sources, text.toString());
  }
}
