import '../models/folio_page.dart';
import 'ai/ai_types.dart';
import '../session/vault_session.dart';

/// Asistencia contextual durante la reunión (Fase 9, inspirado en "Live
/// Assist" de Call.md). No implementa su propio proveedor de IA: usa el
/// `AiService` activo de la sesión, igual que `MeetingNotePreparationService`.
///
/// Deliberadamente NO es un polling automático continuo: el llamador (panel
/// de UI) decide cuándo pedir sugerencias — evita "llenar continuamente la
/// pantalla de sugerencias" y mantiene el control de frecuencia/coste
/// explícito en manos del usuario, no de un timer.
class MeetingNoteLiveAssistService {
  MeetingNoteLiveAssistService._();
  static final MeetingNoteLiveAssistService instance =
      MeetingNoteLiveAssistService._();

  /// Genera hasta 3 sugerencias breves (pregunta a hacer, info que falta,
  /// aclaración pendiente) a partir de una ventana reciente del transcript.
  /// Devuelve lista vacía si no hay `AiService` activo, la página no
  /// existe, o el transcript reciente está vacío.
  Future<List<String>> suggest({
    required VaultSession session,
    required String pageId,
    required String recentTranscript,
  }) async {
    final ai = session.aiService;
    if (ai == null) return const <String>[];

    final trimmedTranscript = recentTranscript.trim();
    if (trimmedTranscript.isEmpty) return const <String>[];

    final page = _pageById(session, pageId);
    final title = page?.title ?? '';

    final prompt =
        'Estás asistiendo en vivo durante una reunión titulada "$title". '
        'Con este fragmento reciente de la conversación transcrita, sugiere '
        'como máximo 3 aportes breves y accionables: una pregunta que '
        'podría hacerse, información que parece faltar, o una aclaración '
        'pendiente. Cada sugerencia en una línea, sin numeración ni '
        'markdown, máximo 15 palabras por línea, en el idioma de la '
        'conversación. Si no hay nada útil que sugerir, responde con una '
        'única línea vacía.\n\n'
        'Fragmento reciente:\n$trimmedTranscript';

    final result = await ai.complete(
      AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        cloudInkOperation: 'meeting_note_live_assist',
        maxTokens: 250,
      ),
    );

    return result.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(3)
        .toList();
  }

  FolioPage? _pageById(VaultSession session, String id) {
    for (final p in session.pages) {
      if (p.id == id) return p;
    }
    return null;
  }
}
