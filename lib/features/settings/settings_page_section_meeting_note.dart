part of 'settings_page.dart';

extension _SettingsPageMeetingNoteSection on _SettingsPageState {
  Widget _buildMeetingNoteSettingsBlock({
    required AppLocalizations l10n,
    required ColorScheme scheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            _SettingsSubsectionTitle(
              title: l10n
                  .meetingNoteSettingsSection,
              scheme: scheme,
              topPadding: 0,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.meetingNoteSettingsDescription,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color:
                        scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (ctx) {
                final hw =
                    TranscriptionHardwareProfile.loadCached();
                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    Text(
                      l10n.meetingNoteSettingsHardwareIntro,
                      style: Theme.of(ctx)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color: scheme
                                .onSurfaceVariant,
                            fontWeight:
                                FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.meetingNoteHardwareSummary(
                        hw.logicalCpuCount,
                        hw.ramLabelForUi(
                          l10n.meetingNoteHardwareRamUnknown,
                        ),
                      ),
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: scheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.meetingNoteHardwareRecommended(
                        _meetingModelLabel(
                          l10n,
                          hw.recommendedWhisperModelId,
                        ),
                      ),
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: scheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      title: Text(
                        l10n.meetingNoteSettingsAutoWhisperModel,
                      ),
                      value: _app
                          .meetingNoteAutoWhisperModel,
                      onChanged: (v) {
                        unawaited(
                          _app.setMeetingNoteAutoWhisperModel(
                            v,
                          ),
                        );
                      },
                    ),
                    if (!hw
                        .isLocalTranscriptionViable) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        title: Text(
                          l10n.meetingNoteSettingsForceLocalTranscription,
                        ),
                        value: _app
                            .meetingNoteForceLocalTranscription,
                        onChanged: (v) {
                          unawaited(
                            _app.setMeetingNoteForceLocalTranscription(
                              v,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'meeting-mic-${_app.meetingNoteMicDeviceId}-${_meetingNoteMicDevices.length}',
              ),
              initialValue: (() {
                final id =
                    _app.meetingNoteMicDeviceId;
                if (id.isEmpty) return '';
                return _meetingMicExists(id)
                    ? id
                    : '';
              })(),
              decoration: InputDecoration(
                labelText: l10n
                    .meetingNoteSettingsMicrophone,
                border:
                    const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: l10n
                      .meetingNoteSettingsRefreshDevices,
                  onPressed:
                      _loadMeetingNoteDevices,
                  icon: const Icon(
                    Icons.refresh,
                  ),
                ),
              ),
              items: _meetingMicDropdownItems(
                l10n,
              ),
              onChanged: (value) {
                unawaited(
                  _app.setMeetingNoteMicDeviceId(
                    value ?? '',
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'meeting-system-${_app.meetingNoteSystemDeviceId}-${_meetingNoteSystemDevices.length}',
              ),
              initialValue: (() {
                final id = _app
                    .meetingNoteSystemDeviceId;
                if (id.isEmpty) return '';
                return _meetingSystemExists(id)
                    ? id
                    : '';
              })(),
              decoration: InputDecoration(
                labelText: l10n
                    .meetingNoteSettingsSystemOutput,
                border:
                    const OutlineInputBorder(),
                isDense: true,
              ),
              items:
                  _meetingSystemDropdownItems(
                    l10n,
                  ),
              onChanged: (value) {
                unawaited(
                  _app.setMeetingNoteSystemDeviceId(
                    value ?? '',
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'meeting-model-${_app.meetingNoteAutoWhisperModel}-${_app.resolvedMeetingNoteWhisperModelId()}',
              ),
              initialValue: (() {
                final id = _app
                    .resolvedMeetingNoteWhisperModelId();
                return _meetingModelExists(id)
                    ? id
                    : 'base';
              })(),
              decoration: InputDecoration(
                labelText: l10n
                    .meetingNoteSettingsModel,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: WhisperService
                  .supportedModels
                  .map(
                    (
                      m,
                    ) => DropdownMenuItem<String>(
                      value: m.id,
                      child: Text(
                        '${_meetingModelLabel(l10n, m.id)} (~${m.approxSizeMb} MB)',
                        maxLines: 1,
                        overflow: TextOverflow
                            .ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged:
                  _app.meetingNoteAutoWhisperModel
                  ? null
                  : (value) {
                      unawaited(
                        _app.setMeetingNoteModelId(
                          value ?? 'base',
                        ),
                      );
                    },
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(
                bottom: 8,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons
                        .record_voice_over_rounded,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.meetingNoteDiarizationHint,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: scheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ],
    );
  }
}
