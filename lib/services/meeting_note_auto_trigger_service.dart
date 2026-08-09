import 'ai/ai_tool_loop.dart';
import 'ai/ai_types.dart';
import 'ai/folio_tool_registry.dart';
import '../session/vault_session.dart';

/// MCP Auto-Triggering (Fase 11), adaptado al `AiToolLoop` genérico ya
/// existente en vez de duplicar un `intent-detector`/`mcp-agent` propio
/// (como hace Call.md): esta clase solo decide QUÉ tools declarar (el
/// subconjunto curado `FolioToolRegistry.meetingAutoTriggerToolNames`) y
/// arma el prompt; `runToolLoop` sigue siendo el único bucle de
/// tool-calling de todo Folio.
///
/// Opt-in explícito: el llamador (UI) solo debe invocar [run] cuando
/// `meetingNoteAutoAssistEnabled` está activo para ese bloque, y debe pedir
/// confirmación de opt-in antes de la primera llamada de la sesión si el
/// proveedor activo es cloud — igual que `MeetingNoteLiveAssistPanel`. Esta
/// clase no gestiona esa confirmación (no tiene contexto de UI), solo
/// ejecuta la pasada una vez que el llamador ya decidió que es seguro.
class MeetingNoteAutoTriggerService {
  MeetingNoteAutoTriggerService._();
  static final MeetingNoteAutoTriggerService instance =
      MeetingNoteAutoTriggerService._();

  /// Ejecuta una pasada de auto-trigger sobre una ventana reciente del
  /// transcript. Devuelve el outcome del tool-loop (puede no tener tool
  /// calls si el modelo decide que no hace falta nada) o `null` si no hay
  /// `AiService` activo o el transcript está vacío.
  Future<AiToolLoopOutcome?> run({
    required VaultSession session,
    required String pageId,
    required String blockId,
    required String recentTranscript,
  }) async {
    final ai = session.aiService;
    if (ai == null) return null;
    final trimmed = recentTranscript.trim();
    if (trimmed.isEmpty) return null;

    final registry = FolioToolRegistry(session, scopePageId: pageId);
    final allowed = FolioToolRegistry.meetingAutoTriggerToolNames.toSet();
    final curatedTools = registry.definitions
        .where((d) => allowed.contains(d.name))
        .toList(growable: false);
    if (curatedTools.isEmpty) return null;

    final prompt =
        'Estás monitorizando en vivo la transcripción de una reunión '
        '(bloque meeting_note, id: $blockId, página: $pageId). Con este '
        'fragmento reciente, invoca UNA tool solo si detectas una '
        'necesidad clara y concreta: pedir contexto de la página '
        '(meeting_get_context), marcar un momento importante '
        '(meeting_create_bookmark) si se acaba de tomar una decisión o '
        'acción explícita, o generar un checklist '
        '(meeting_generate_checklist) si se enumeraron varias acciones '
        'pendientes. Si nada de esto aplica claramente, NO invoques '
        'ninguna tool y responde solo con una línea vacía. No inventes '
        'información que no esté en el fragmento.\n\n'
        'Fragmento reciente:\n$trimmed';

    // Defensa en profundidad: aunque solo se declaran las tools curadas al
    // modelo, algunos backends (sobre todo la emulación JSON de tool-calls)
    // no garantizan que el modelo respete esa lista. Se rechaza cualquier
    // llamada fuera del allowlist antes de tocar el vault.
    Future<AiToolResult> guardedExecute(AiToolCall call) async {
      if (!allowed.contains(call.name)) {
        return AiToolResult.error(
          call.id,
          'Tool no permitida en auto-trigger de meeting_note: ${call.name}',
        );
      }
      return registry.execute(call);
    }

    return runToolLoop(
      ai: ai,
      baseRequest: AiCompletionRequest(
        prompt: prompt,
        model: 'auto',
        cloudInkOperation: 'meeting_note_auto_trigger',
        maxTokens: 300,
        tools: curatedTools,
      ),
      tools: curatedTools,
      executeTool: guardedExecute,
      maxSteps: 2,
    );
  }
}
