part of 'workspace_page.dart';

extension _WorkspacePageAiAttachmentsModule on _WorkspacePageState {
  Future<List<AiFileAttachment>> _collectAiAttachments() async {
    final regularPaths = <String>[];
    final audioOnlyPaths = <String>[];
    final pendingTranscripts = <String>[];

    for (final path in _aiAttachmentPaths) {
      final payload = _aiMeetingPayloads[path];
      if (payload == null) {
        regularPaths.add(path);
        continue;
      }
      final transcript = _aiMeetingTranscripts[path] ?? '';
      if (payload == _MeetingNoteAiPayload.transcript ||
          payload == _MeetingNoteAiPayload.both) {
        if (transcript.isNotEmpty) {
          pendingTranscripts.add(transcript);
        }
      }
      if (payload == _MeetingNoteAiPayload.audio ||
          payload == _MeetingNoteAiPayload.both) {
        audioOnlyPaths.add(path);
      }
    }

    final out = await _s.buildAiAttachmentsFromPaths([
      ...regularPaths,
      ...audioOnlyPaths,
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
    return url.isNotEmpty ? url : 'Nota de reunión';
  }

  bool _meetingNoteHasTranscriptForAi(FolioBlock b) {
    if (b.meetingNoteTranscriptionEnabled == false) return false;
    return b.text.trim().isNotEmpty;
  }

  String _meetingNoteChipLabel(AppLocalizations l10n, String path) {
    final payload = _aiMeetingPayloads[path] ?? _MeetingNoteAiPayload.both;
    final suffix = switch (payload) {
      _MeetingNoteAiPayload.transcript => l10n.meetingNoteAiPayloadTranscript,
      _MeetingNoteAiPayload.audio => l10n.meetingNoteAiPayloadAudio,
      _MeetingNoteAiPayload.both => l10n.meetingNoteAiPayloadBoth,
    };
    return '🎙 $suffix';
  }

  Future<void> _pickMeetingNoteAttachment() async {
    final page = _s.selectedPage;
    if (page == null || !mounted) return;

    final meetingBlocks = page.blocks
        .where(
          (b) => b.type == 'meeting_note' && (b.url ?? '').trim().isNotEmpty,
        )
        .toList();
    if (meetingBlocks.isEmpty) return;

    final l10n = AppLocalizations.of(context);

    FolioBlock? picked = meetingBlocks.length == 1 ? meetingBlocks.first : null;
    var payload = (picked != null && _meetingNoteHasTranscriptForAi(picked))
        ? _MeetingNoteAiPayload.both
        : _MeetingNoteAiPayload.audio;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
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
                      'Selecciona la nota:',
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
                        onTap: () => setS(() {
                          picked = b;
                          if (!_meetingNoteHasTranscriptForAi(b)) {
                            if (payload == _MeetingNoteAiPayload.transcript ||
                                payload == _MeetingNoteAiPayload.both) {
                              payload = _MeetingNoteAiPayload.audio;
                            }
                          }
                        }),
                      ),
                    ),
                    const Divider(),
                  ],
                  Text(
                    l10n.meetingNoteAiPayloadLabel,
                    style: Theme.of(ctx).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (ctx2) {
                      final canTranscript =
                          picked != null &&
                          _meetingNoteHasTranscriptForAi(picked!);
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(l10n.meetingNoteAiPayloadTranscript),
                            selected:
                                payload == _MeetingNoteAiPayload.transcript,
                            onSelected: canTranscript
                                ? (_) => setS(
                                    () => payload =
                                        _MeetingNoteAiPayload.transcript,
                                  )
                                : null,
                          ),
                          ChoiceChip(
                            label: Text(l10n.meetingNoteAiPayloadAudio),
                            selected: payload == _MeetingNoteAiPayload.audio,
                            onSelected: (_) => setS(
                              () => payload = _MeetingNoteAiPayload.audio,
                            ),
                          ),
                          ChoiceChip(
                            label: Text(l10n.meetingNoteAiPayloadBoth),
                            selected: payload == _MeetingNoteAiPayload.both,
                            onSelected: canTranscript
                                ? (_) => setS(
                                    () => payload = _MeetingNoteAiPayload.both,
                                  )
                                : null,
                          ),
                        ],
                      );
                    },
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

