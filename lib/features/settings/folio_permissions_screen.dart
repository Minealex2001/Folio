import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/media/system_media_controller.dart';

enum _PermissionStatus { granted, denied, notApplicable }

/// Fase 3 del roadmap de producto (idea #7, "Permisos") — no existía
/// ninguna pantalla que agregara qué accede Folio al sistema. Deliberadamente
/// NO se añade `permission_handler` como dependencia nueva: cada permiso
/// real que Folio ya gestiona tiene su propio check ya funcionando
/// (`AudioRecorder.hasPermission()` del paquete `record`, ya usado en
/// `audio_mixer_service.dart`; `SystemMediaController.instance.hasPermission`,
/// ya usado en la integración de "reproduciendo ahora") — reusarlos evita
/// una segunda vía de permisos para el mismo permiso del SO. Notificaciones/
/// archivos/calendario se muestran con su estado REAL de "no implementado",
/// no con un toggle falso: Folio hoy usa banners in-app para recordatorios
/// (ver comentario explícito en `task_reminder_service.dart`), no
/// notificaciones del SO, y no tiene ninguna integración de calendario —
/// fingir un permiso que no protege ninguna funcionalidad real sería
/// justo el "relleno" que el resto de este catálogo evita.
class FolioPermissionsScreen extends StatefulWidget {
  const FolioPermissionsScreen({super.key});

  @override
  State<FolioPermissionsScreen> createState() => _FolioPermissionsScreenState();
}

class _FolioPermissionsScreenState extends State<FolioPermissionsScreen> {
  bool? _micGranted;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshMic());
  }

  Future<void> _refreshMic() async {
    final granted = await AudioRecorder().hasPermission();
    if (!mounted) return;
    setState(() => _micGranted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final media = SystemMediaController.instance;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.permissionsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListenableBuilder(
            listenable: media,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  Text(
                    l10n.permissionsIntro,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PermissionRow(
                    icon: Icons.mic_none_rounded,
                    title: l10n.permissionsMicTitle,
                    explanation: l10n.permissionsMicExplanation,
                    status: _micGranted == null
                        ? null
                        : (_micGranted!
                            ? _PermissionStatus.granted
                            : _PermissionStatus.denied),
                    onRefresh: _refreshMic,
                  ),
                  const Divider(height: 24),
                  _PermissionRow(
                    icon: Icons.music_note_rounded,
                    title: l10n.permissionsSystemAudioTitle,
                    explanation: l10n.permissionsSystemAudioExplanation,
                    status: !media.platformSupported
                        ? _PermissionStatus.notApplicable
                        : (media.hasPermission
                            ? _PermissionStatus.granted
                            : _PermissionStatus.denied),
                    onConfigure: media.platformSupported && !media.hasPermission
                        ? () => unawaited(media.openPermissionSettings())
                        : null,
                    onRefresh: media.platformSupported
                        ? () => unawaited(media.refreshCapability())
                        : null,
                  ),
                  const Divider(height: 24),
                  _PermissionRow(
                    icon: Icons.notifications_none_rounded,
                    title: l10n.permissionsNotificationsTitle,
                    explanation: l10n.permissionsNotificationsExplanation,
                    status: null,
                    notImplementedLabel: l10n.permissionsNotImplemented,
                  ),
                  const Divider(height: 24),
                  _PermissionRow(
                    icon: Icons.folder_open_rounded,
                    title: l10n.permissionsFilesTitle,
                    explanation: l10n.permissionsFilesExplanation,
                    status: _PermissionStatus.notApplicable,
                  ),
                  const Divider(height: 24),
                  _PermissionRow(
                    icon: Icons.event_outlined,
                    title: l10n.permissionsCalendarTitle,
                    explanation: l10n.permissionsCalendarExplanation,
                    status: null,
                    notImplementedLabel: l10n.permissionsNotRequested,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.explanation,
    required this.status,
    this.onConfigure,
    this.onRefresh,
    this.notImplementedLabel,
  });

  final IconData icon;
  final String title;
  final String explanation;
  final _PermissionStatus? status;
  final VoidCallback? onConfigure;
  final VoidCallback? onRefresh;
  final String? notImplementedLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    Widget statusChip() {
      if (status == null) {
        return Text(
          notImplementedLabel ?? '',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        );
      }
      switch (status!) {
        case _PermissionStatus.granted:
          return Text(
            l10n.permissionsGranted,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          );
        case _PermissionStatus.denied:
          return Text(
            l10n.permissionsDenied,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
          );
        case _PermissionStatus.notApplicable:
          return Text(
            l10n.permissionsManagedBySystem,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          );
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  statusChip(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                explanation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onConfigure != null || onRefresh != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (onConfigure != null)
                      TextButton(
                        onPressed: onConfigure,
                        child: Text(l10n.permissionsConfigure),
                      ),
                    if (onRefresh != null)
                      TextButton(
                        onPressed: onRefresh,
                        child: Text(l10n.permissionsRefresh),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
