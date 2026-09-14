part of 'workspace_page.dart';

extension _WorkspacePageAiAttachmentsModule on _WorkspacePageState {
  Future<List<AiFileAttachment>> _collectAiAttachments() async {
    final regularPaths = <String>[];
    final audioPaths = <String>[];
    final pendingTranscripts = <String>[];

    for (final path in _aiAttachmentPaths) {
      final payload = _aiMeetingPayloads[path];
      if (payload == null) {
        regularPaths.add(path);
        continue;
      }
      final transcript = _aiMeetingTranscripts[path] ?? '';
      if (transcript.isNotEmpty) {
        pendingTranscripts.add(transcript);
      }
      // `both` sigue incluyendo también el audio bruto además de la
      // transcripción (no se toca en esta fase) — solo se quitó la opción
      // de adjuntar audio SIN transcripción, que era un placebo.
      if (payload == _MeetingNoteAiPayload.both) {
        audioPaths.add(path);
      }
    }

    final out = await _s.buildAiAttachmentsFromPaths([
      ...regularPaths,
      ...audioPaths,
    ]);
    for (final text in pendingTranscripts) {
      out.add(
        AiFileAttachment(
          name: 'meeting_transcript.txt',
          mimeType: 'text/plain',
          content: text,
        ),
      );
    }
    return out;
  }

  String _meetingNoteBlockTitle(FolioBlock b) {
    // Intenta extraer fecha del nombre del archivo si la transcripción está vacía.
    final text = b.text.trim();
    if (text.isNotEmpty) {
      final preview = text.length > 60 ? '${text.substring(0, 60)}…' : text;
      return preview;
    }
    final url = (b.url ?? '').split(RegExp(r'[/\\]')).last;
    return url.isNotEmpty ? url : AppLocalizations.of(context).meetingNoteFallbackTitle;
  }

  bool _meetingNoteHasTranscriptForAi(FolioBlock b) {
    if (b.meetingNoteTranscriptionEnabled == false) return false;
    return b.text.trim().isNotEmpty;
  }

  String _meetingNoteChipLabel(AppLocalizations l10n, String path) {
    final payload = _aiMeetingPayloads[path] ?? _MeetingNoteAiPayload.both;
    // Fase 8 de Quill 2.0 — antes llevaba un prefijo de emoji '🎙 ' propio,
    // redundante con el `avatar: Icon(Icons.mic_rounded, ...)` que el chip
    // (InputChip en workspace_page_ai_panel.dart) ya pone junto al texto.
    return switch (payload) {
      _MeetingNoteAiPayload.transcript => l10n.meetingNoteAiPayloadTranscript,
      _MeetingNoteAiPayload.both => l10n.meetingNoteAiPayloadBoth,
    };
  }

  Future<void> _pickMeetingNoteAttachment() async {
    final page = _s.selectedPage;
    if (page == null || !mounted) return;

    // Solo notas con transcripción — sin `audio` (adjuntar solo el .wav), el
    // resto de opciones (`transcript`/`both`) requieren transcripción.
    final meetingBlocks = page.blocks
        .where(
          (b) =>
              b.type == 'meeting_note' &&
              (b.url ?? '').trim().isNotEmpty &&
              _meetingNoteHasTranscriptForAi(b),
        )
        .toList();
    if (meetingBlocks.isEmpty) return;

    final l10n = AppLocalizations.of(context);

    FolioBlock? picked = meetingBlocks.length == 1 ? meetingBlocks.first : null;
    var payload = _MeetingNoteAiPayload.both;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => FolioDialog(
          title: Text(l10n.meetingNoteSendToAi),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meetingBlocks.length > 1) ...[
                    Text(
                      l10n.meetingNoteSelectNote,
                      style: Theme.of(ctx).textTheme.labelMedium,
                    ),
                    ...meetingBlocks.map(
                      (b) => ListTile(
                        dense: true,
                        leading: Icon(
                          picked?.id == b.id
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: picked?.id == b.id
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          _meetingNoteBlockTitle(b),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => setS(() => picked = b),
                      ),
                    ),
                    const Divider(),
                  ],
                  Text(
                    l10n.meetingNoteAiPayloadLabel,
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.meetingNoteAiPayloadTranscript),
                        selected: payload == _MeetingNoteAiPayload.transcript,
                        onSelected: (_) => setS(
                          () => payload = _MeetingNoteAiPayload.transcript,
                        ),
                      ),
                      ChoiceChip(
                        label: Text(l10n.meetingNoteAiPayloadBoth),
                        selected: payload == _MeetingNoteAiPayload.both,
                        onSelected: (_) => setS(
                          () => payload = _MeetingNoteAiPayload.both,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: picked == null ? null : () => Navigator.pop(ctx, true),
              child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || picked == null || !mounted) return;

    final vault = await VaultPaths.vaultDirectory();
    final relUrl = picked!.url!.trim();
    final absPath = p.join(vault.path, relUrl.replaceAll('/', p.separator));

    if (_aiAttachmentPaths.contains(absPath)) return;

    _setStateSafe(() {
      _aiAttachmentPaths.add(absPath);
      _aiMeetingPayloads[absPath] = payload;
      _aiMeetingTranscripts[absPath] = picked!.text;
    });
    _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
  }

  Future<void> _pickAiAttachments() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) return;
    for (final f in result.files) {
      final path = f.path;
      if (path == null || path.trim().isEmpty) continue;
      if (!_aiAttachmentPaths.contains(path)) {
        _aiAttachmentPaths.add(path);
      }
    }
    if (mounted) {
      _setStateSafe(() {});
      _s.syncActiveAiChatAttachmentPaths(_aiAttachmentPaths);
    }
  }
}

