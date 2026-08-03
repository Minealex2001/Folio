import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/block.dart';
import '../../../models/folio_page.dart';
import '../../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../../services/meeting_note_posthoc_transcription_manager.dart';
import '../../../services/wav_chunk_splitter.dart';
import '../../../session/vault_session.dart';

class _PostHocLanguageOption {
  const _PostHocLanguageOption({required this.code, required this.labelKey});

  final String code;
  final String labelKey;
}

const _postHocLanguageOptions = [
  _PostHocLanguageOption(code: 'auto', labelKey: 'meetingNoteLangAuto'),
  _PostHocLanguageOption(code: 'es', labelKey: 'meetingNoteLangEs'),
  _PostHocLanguageOption(code: 'en', labelKey: 'meetingNoteLangEn'),
  _PostHocLanguageOption(code: 'pt', labelKey: 'meetingNoteLangPt'),
  _PostHocLanguageOption(code: 'fr', labelKey: 'meetingNoteLangFr'),
  _PostHocLanguageOption(code: 'it', labelKey: 'meetingNoteLangIt'),
  _PostHocLanguageOption(code: 'de', labelKey: 'meetingNoteLangDe'),
];

String _resolvePostHocLanguageLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'meetingNoteLangAuto' => l10n.meetingNoteLangAuto,
    'meetingNoteLangEs' => l10n.meetingNoteLangEs,
    'meetingNoteLangEn' => l10n.meetingNoteLangEn,
    'meetingNoteLangPt' => l10n.meetingNoteLangPt,
    'meetingNoteLangFr' => l10n.meetingNoteLangFr,
    'meetingNoteLangIt' => l10n.meetingNoteLangIt,
    'meetingNoteLangDe' => l10n.meetingNoteLangDe,
    _ => l10n.meetingNoteLangAuto,
  };
}

/// Diálogo para pedir la transcripción a posteriori de una nota de reunión
/// que tiene audio guardado pero no transcripción (desactivada al grabar, o
/// fallida/vacía). A diferencia del flujo de grabación, aquí el motor y el
/// idioma se preguntan siempre — no hay nada persistido por bloque que
/// reutilizar en silencio. Al confirmar, arranca el job en segundo plano
/// (`PostHocTranscriptionJobManager`) y cierra — el progreso se ve en el
/// propio bloque, no en este diálogo.
Future<void> showPostHocTranscribeDialog({
  required BuildContext context,
  required VaultSession session,
  required AppSettings appSettings,
  required FolioPage page,
  required FolioBlock block,
  required File audioFile,
  FolioCloudEntitlementsController? entitlements,
}) async {
  final cloudAllowed =
      appSettings.isAiRuntimeEnabled &&
      (entitlements?.snapshot.canUseCloudAi ?? false);

  Duration? estimatedDuration;
  try {
    estimatedDuration = await WavChunkSplitter.estimateDuration(audioFile);
  } catch (_) {
    estimatedDuration = null;
  }

  if (!context.mounted) return;

  var engine = PostHocTranscriptionEngine.local;
  var languageCode = 'auto';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final l10n = AppLocalizations.of(dialogContext);
          final theme = Theme.of(dialogContext);
          final duration = estimatedDuration;
          final inkCost = duration == null
              ? null
              : math.max(1, (duration.inSeconds / 300).ceil());

          return AlertDialog(
            title: Text(l10n.meetingNoteTranscribeNow),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<PostHocTranscriptionEngine>(
                  segments: [
                    ButtonSegment(
                      value: PostHocTranscriptionEngine.local,
                      label: Text(l10n.meetingNoteProviderLocal),
                      icon: const Icon(Icons.computer_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: PostHocTranscriptionEngine.quillCloud,
                      label: Text(l10n.meetingNoteProviderCloud),
                      icon: const Icon(Icons.cloud_rounded, size: 16),
                      enabled: cloudAllowed,
                    ),
                  ],
                  selected: {engine},
                  onSelectionChanged: (selected) {
                    setDialogState(() => engine = selected.first);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: languageCode,
                  decoration: InputDecoration(
                    labelText: l10n.meetingNoteTranscriptionLanguage,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _postHocLanguageOptions
                      .map(
                        (o) => DropdownMenuItem<String>(
                          value: o.code,
                          child: Text(
                            _resolvePostHocLanguageLabel(l10n, o.labelKey),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(
                      () => languageCode = (value ?? 'auto').trim(),
                    );
                  },
                ),
                if (engine == PostHocTranscriptionEngine.quillCloud &&
                    inkCost != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.meetingNotePostHocCloudCostEstimate(inkCost),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.meetingNoteTranscribeNow),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true) return;

  final modelId = appSettings.resolvedMeetingNoteWhisperModelId();
  await PostHocTranscriptionJobManager.instance.start(
    session: session,
    pageId: page.id,
    blockId: block.id,
    audioFile: audioFile,
    engine: engine,
    languageCode: languageCode,
    modelId: modelId,
    entitlements: entitlements,
  );
}
