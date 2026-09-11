import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/ai/ai_tool_loop.dart';
import '../../../services/meeting_note_auto_trigger_service.dart';
import '../../../services/meeting_note_live_assist_service.dart';
import '../../../services/meeting_note_session_controller.dart';
import '../../../session/vault_session.dart';

/// Panel de asistencia en vivo + nudges (Fases 9 y 10 de la evolución de
/// `meeting_note`). Superficie nueva y genuina — no hay dónde encajar esto
/// en `meeting_note_block_widget.dart` sin sobrecargarlo — pero reutiliza
/// `MeetingNoteLiveAssistService`/`MeetingMetricsService` para toda la
/// lógica; este widget solo dibuja.
///
/// Disparo manual, no polling automático: el botón "Sugerir" es el único
/// punto de entrada a una llamada IA, así que la frecuencia de llamadas
/// (y su coste si el proveedor es cloud) queda siempre bajo control
/// explícito del usuario.
class MeetingNoteLiveAssistPanel extends StatefulWidget {
  const MeetingNoteLiveAssistPanel({
    super.key,
    required this.session,
    required this.appSettings,
    required this.pageId,
    required this.blockId,
    required this.scheme,
    this.initialAutoAssistEnabled = false,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final String pageId;
  final String blockId;
  final ColorScheme scheme;

  /// Valor persistido de `FolioBlock.meetingNoteAutoAssistEnabled` (Fase 11).
  final bool initialAutoAssistEnabled;

  @override
  State<MeetingNoteLiveAssistPanel> createState() =>
      _MeetingNoteLiveAssistPanelState();
}

class _MeetingNoteLiveAssistPanelState
    extends State<MeetingNoteLiveAssistPanel> {
  bool _expanded = false;
  bool _loading = false;
  bool _cloudOptInConfirmed = false;
  List<String> _suggestions = const [];
  String? _error;
  String? _dismissedNudgeCode;
  String? _activeNudgeCode;
  bool _autoAssistEnabled = false;
  List<AiToolLoopStepRecord> _autoTriggerSteps = const [];

  @override
  void initState() {
    super.initState();
    _autoAssistEnabled = widget.initialAutoAssistEnabled;
  }

  MeetingNoteSessionController get _controller =>
      MeetingNoteSessionController.instance;

  bool get _isCloudProvider =>
      widget.appSettings.aiProvider == AiProvider.quillCloud;

  /// Toma la ventana reciente del transcript (últimos ~1500 caracteres,
  /// suficiente para unos minutos de conversación) sin cargar la
  /// transcripción completa en cada llamada — evita el "reconstrucción
  /// completa del transcript en cada interacción" que la Fase 22 (perf)
  /// pide evitar, aplicado ya desde aquí.
  String get _recentTranscriptWindow {
    final full = _controller.transcript;
    const maxChars = 1500;
    if (full.length <= maxChars) return full;
    return full.substring(full.length - maxChars);
  }

  Future<bool> _ensureCloudOptIn() async {
    if (!_isCloudProvider || _cloudOptInConfirmed) return true;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.meetingNoteLiveAssistCloudOptInTitle),
        content: Text(l10n.meetingNoteLiveAssistCloudOptInBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.meetingNoteCancelUpload),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.meetingNoteLiveAssistCloudOptInConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    if (!mounted) return false;
    setState(() => _cloudOptInConfirmed = true);
    return true;
  }

  void _toggleAutoAssist(bool value) {
    setState(() => _autoAssistEnabled = value);
    widget.session.updateBlockMeetingNoteAutoAssistEnabled(
      widget.pageId,
      widget.blockId,
      value ? true : null,
    );
  }

  Future<void> _requestSuggestions() async {
    if (!await _ensureCloudOptIn()) return;

    setState(() {
      _loading = true;
      _error = null;
      _autoTriggerSteps = const [];
    });
    try {
      final recent = _recentTranscriptWindow;
      final suggestions = await MeetingNoteLiveAssistService.instance.suggest(
        session: widget.session,
        pageId: widget.pageId,
        recentTranscript: recent,
      );

      // Fase 11: si el auto-assist está activado, esta misma pulsación
      // también ejecuta UNA pasada de auto-trigger MCP (subconjunto curado
      // de tools) — no hay un timer separado disparándolo solo.
      List<AiToolLoopStepRecord> autoSteps = const [];
      if (_autoAssistEnabled) {
        final outcome = await MeetingNoteAutoTriggerService.instance.run(
          session: widget.session,
          pageId: widget.pageId,
          blockId: widget.blockId,
          recentTranscript: recent,
        );
        autoSteps = outcome?.steps ?? const [];
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _suggestions = suggestions;
        _autoTriggerSteps = autoSteps;
        if (suggestions.isEmpty && autoSteps.isEmpty) {
          _error = AppLocalizations.of(context).meetingNoteLiveAssistEmpty;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).meetingNoteLiveAssistFailed;
      });
    }
  }

  /// Fase 12: MCP Results Panel — formatea el resultado de cada tool-call
  /// del auto-trigger para mostrarlo inline. Reutiliza `AiToolResult`
  /// (`ai_tool.dart`), sin un sistema de resultados nuevo.
  String _formatToolStep(AppLocalizations l10n, AiToolLoopStepRecord step) {
    if (step.result.isError) {
      return l10n.meetingNoteMcpResultError(step.call.name);
    }
    return switch (step.call.name) {
      'meeting_create_bookmark' => l10n.meetingNoteMcpResultBookmark,
      'meeting_generate_checklist' => l10n.meetingNoteMcpResultChecklist,
      'meeting_get_context' => l10n.meetingNoteMcpResultContext,
      _ => step.call.name,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Fase 10: consulta el nudge activo (rate-limited internamente por el
    // controller) cada vez que este panel se reconstruye — el timer de
    // `elapsed` del controller ya dispara un rebuild por segundo mientras
    // se graba, así que no hace falta un timer propio aquí.
    final nudge = _controller.consumeActiveNudge();
    if (nudge != null && nudge != _dismissedNudgeCode) {
      _activeNudgeCode = nudge;
    }
    final showNudge =
        _activeNudgeCode != null && _activeNudgeCode != _dismissedNudgeCode;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: widget.scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 16,
                    color: widget.scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.meetingNoteLiveAssistTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: widget.scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (showNudge)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: widget.scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _nudgeText(l10n, _activeNudgeCode!),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    InkWell(
                      onTap: () =>
                          setState(() => _dismissedNudgeCode = _activeNudgeCode),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: widget.scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fase 11: opt-in explícito por bloque, persistido — nunca
                  // activo por defecto.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.meetingNoteAutoAssistToggle,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      Switch(
                        value: _autoAssistEnabled,
                        onChanged: _toggleAutoAssist,
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _loading ? null : _requestSuggestions,
                      icon: _loading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: widget.scheme.primary,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_outlined, size: 16),
                      label: Text(l10n.meetingNoteLiveAssistSuggest),
                    ),
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: widget.scheme.onSurfaceVariant,
                      ),
                    ),
                  for (final s in _suggestions)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 4,
                            color: widget.scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SelectableText(
                              s,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_autoTriggerSteps.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 2),
                      child: Text(
                        l10n.meetingNoteMcpResultsTitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: widget.scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final step in _autoTriggerSteps)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              step.result.isError
                                  ? Icons.error_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 13,
                              color: step.result.isError
                                  ? widget.scheme.error
                                  : widget.scheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatToolStep(l10n, step),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _nudgeText(AppLocalizations l10n, String code) => switch (code) {
    'monologue_long' => l10n.meetingNoteNudgeMonologueLong,
    _ => '',
  };
}
