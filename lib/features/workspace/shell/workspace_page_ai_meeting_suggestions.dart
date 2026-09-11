part of 'workspace_page.dart';

/// Fase A3 del plan Quill/MCP — sugerencia proactiva, alcance de v1
/// deliberadamente acotado a un único disparador de alta confianza:
/// transcripción de una reunión completada. Construir un motor genérico de
/// detección de patrones (el resto de ejemplos del documento original —
/// "POST /login" → generar OpenAPI, "reunión mañana" → crear evento) queda
/// explícitamente fuera de alcance por ser lo más especulativo/caro del
/// plan; este archivo cubre solo la señal que ya está instrumentada.
///
/// Escucha `MeetingNoteSessionController.instance` (un `ChangeNotifier` ya
/// existente) puramente desde fuera — no toca ningún archivo del
/// subsistema de audio/transcripción, que en el momento de esta fase está
/// bajo reescritura activa en paralelo.
extension _WorkspacePageAiMeetingSuggestionsModule on _WorkspacePageState {
  void _onMeetingSessionStateChanged() {
    final ctrl = MeetingNoteSessionController.instance;
    final decision = meetingCompletionSuggestionDecision(
      previousState: _lastObservedMeetingSessionState,
      currentState: ctrl.state,
      pageId: ctrl.pageId,
      blockId: ctrl.blockId,
      transcript: ctrl.transcript,
      alreadyShownKeys: _shownMeetingSuggestionKeys,
      enabled: widget.appSettings.proactiveSuggestionsEnabled,
    );
    _lastObservedMeetingSessionState = ctrl.state;
    if (!decision.shouldShow) return;

    // Descartable de verdad: una vez mostrada (se ignore o se use) para esta
    // sesión de reunión concreta, no se repite — ni siquiera si el usuario
    // vuelve a pasar por esta página.
    _shownMeetingSuggestionKeys.add(decision.key!);

    final pageId = decision.pageId!;
    final blockId = decision.blockId!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMeetingExtractSuggestion(pageId: pageId, blockId: blockId);
    });
  }

  void _showMeetingExtractSuggestion({
    required String pageId,
    required String blockId,
  }) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.meetingSuggestionExtractActionItems),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: l10n.meetingSuggestionExtractActionButton,
          onPressed: () => unawaited(
            _openMeetingSuggestionTarget(pageId: pageId, blockId: blockId),
          ),
        ),
      ),
    );
  }

  /// Navega a la página de la reunión y abre el popover de IA (Fase D1) ya
  /// anclado a ese bloque — mismo pipeline que el botón manual de D3, esta
  /// fase solo añade un disparador proactivo adicional.
  Future<void> _openMeetingSuggestionTarget({
    required String pageId,
    required String blockId,
  }) async {
    _s.selectPage(pageId);
    // Deja que `BlockEditor` se monte/reconstruya para la página recién
    // seleccionada antes de intentar abrir el popover anclado a un bloque
    // suyo (el `GlobalKey` de esa página puede no tener `currentState`
    // hasta el siguiente frame si la página no estaba ya abierta).
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _blockEditorKeyForPage(pageId).currentState?.showAiSelectionPopover(
          blockId: blockId,
        );
  }
}

/// Resultado puro de [meetingCompletionSuggestionDecision] — separado de
/// `_WorkspacePageState` a propósito para poder testear la lógica de
/// decisión (cuándo mostrar la sugerencia) sin depender del
/// `MeetingNoteSessionController` real ni de un `WorkspacePage` montado.
class MeetingCompletionSuggestionDecision {
  const MeetingCompletionSuggestionDecision._({
    required this.shouldShow,
    this.pageId,
    this.blockId,
    this.key,
  });

  final bool shouldShow;
  final String? pageId;
  final String? blockId;
  final String? key;
}

/// Fase A3 — decide si corresponde mostrar la sugerencia "¿extraer tareas?"
/// ante un cambio de estado del `MeetingNoteSessionController`. Pura: no
/// muta nada, no depende de `BuildContext` ni del singleton real — el
/// llamador (`_onMeetingSessionStateChanged`) es quien aplica el efecto.
MeetingCompletionSuggestionDecision meetingCompletionSuggestionDecision({
  required MeetingNoteSessionState? previousState,
  required MeetingNoteSessionState currentState,
  required String? pageId,
  required String? blockId,
  required String transcript,
  required Set<String> alreadyShownKeys,
  required bool enabled,
}) {
  const none = MeetingCompletionSuggestionDecision._(shouldShow: false);
  if (!enabled) return none;
  // Solo interesa la TRANSICIÓN a completed, no cada notifyListeners()
  // mientras ya está completed (evita reabrir el snack en cada rebuild).
  if (previousState == currentState) return none;
  if (currentState != MeetingNoteSessionState.completed) return none;
  if (pageId == null || blockId == null) return none;
  if (transcript.trim().isEmpty) return none;

  final key = '$pageId#$blockId';
  if (alreadyShownKeys.contains(key)) return none;

  return MeetingCompletionSuggestionDecision._(
    shouldShow: true,
    pageId: pageId,
    blockId: blockId,
    key: key,
  );
}
