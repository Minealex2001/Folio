import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../app/widgets/integration_settings_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/system_media_integration_state.dart';
import '../../services/media/system_media_controller.dart';
import '../../services/media/system_media_service.dart';
import '../../session/vault_session.dart';

class SystemMediaIntegrationCard extends StatefulWidget {
  const SystemMediaIntegrationCard({
    super.key,
    required this.session,
  });

  final VaultSession session;

  static const _brandColor = Color(0xFF5C6BC0);

  @override
  State<SystemMediaIntegrationCard> createState() =>
      _SystemMediaIntegrationCardState();
}

class _SystemMediaIntegrationCardState
    extends State<SystemMediaIntegrationCard> {
  bool _supported = false;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final ctrl = SystemMediaController.instance;
    await ctrl.refreshCapability();
    if (!mounted) return;
    setState(() {
      _supported = ctrl.platformSupported;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final state = widget.session.systemMediaIntegrationState;
        return IntegrationCard(
          brandIcon: Icons.devices_rounded,
          brandColor: SystemMediaIntegrationCard._brandColor,
          title: l10n.systemMediaIntegrationTitle,
          subtitle: l10n.systemMediaCardSubtitle,
          configureLabel: l10n.systemMediaConfigure,
          onConfigure: widget.session.state == VaultFlowState.unlocked
              ? () => showIntegrationConfigSheet(
                    context: context,
                    builder: (ctx) => SystemMediaIntegrationConfigDialog(
                      session: widget.session,
                    ),
                  )
              : null,
          chips: [
            IntegrationStatChip(
              icon: state.enabled
                  ? Icons.check_circle_outline_rounded
                  : Icons.radio_button_unchecked_rounded,
              label: state.enabled
                  ? l10n.systemMediaStatusEnabled
                  : l10n.systemMediaStatusDisabled,
            ),
            if (!_loading && !_supported)
              IntegrationStatChip(
                icon: Icons.info_outline_rounded,
                label: l10n.systemMediaUnsupportedPlatform,
              ),
          ],
        );
      },
    );
  }
}

class SystemMediaIntegrationConfigDialog extends StatefulWidget {
  const SystemMediaIntegrationConfigDialog({
    super.key,
    required this.session,
  });

  final VaultSession session;

  @override
  State<SystemMediaIntegrationConfigDialog> createState() =>
      _SystemMediaIntegrationConfigDialogState();
}

class _SystemMediaIntegrationConfigDialogState
    extends State<SystemMediaIntegrationConfigDialog> {
  bool _supported = false;
  bool _permission = true;

  @override
  void initState() {
    super.initState();
    SystemMediaController.instance.attachSession(widget.session);
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final ctrl = SystemMediaController.instance;
    await ctrl.refreshCapability();
    if (!mounted) return;
    setState(() {
      _supported = ctrl.platformSupported;
      _permission = ctrl.hasPermission;
    });
  }

  void _update(SystemMediaIntegrationState next) {
    widget.session.updateSystemMediaIntegration(next);
    setState(() {});
  }

  Widget _info(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.session.systemMediaIntegrationState;
    final scheme = Theme.of(context).colorScheme;
    final platformOk =
        !kIsWeb && SystemMediaService.isPlatformCandidate && _supported;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.systemMediaIntegrationTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.systemMediaHelp,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        if (!platformOk) ...[
          _info(context, l10n.systemMediaUnsupportedPlatformDetail),
          const SizedBox(height: 12),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.systemMediaEnable),
          subtitle: Text(l10n.systemMediaEnableHint),
          value: state.enabled,
          onChanged: (!platformOk ||
                  widget.session.state != VaultFlowState.unlocked)
              ? null
              : (v) => _update(state.copyWith(enabled: v)),
        ),
        if (platformOk && !_permission) ...[
          const SizedBox(height: 8),
          _info(context, l10n.systemMediaPermissionNeeded),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await SystemMediaController.instance.openPermissionSettings();
              await _refresh();
            },
            icon: const Icon(Icons.settings_rounded),
            label: Text(l10n.systemMediaOpenPermissionSettings),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.systemMediaZenPauseOnExit),
          subtitle: Text(l10n.systemMediaZenPauseOnExitHint),
          value: state.zenPauseOnExit,
          onChanged: (!state.enabled ||
                  widget.session.state != VaultFlowState.unlocked)
              ? null
              : (v) => _update(state.copyWith(zenPauseOnExit: v)),
        ),
      ],
    );
  }
}
