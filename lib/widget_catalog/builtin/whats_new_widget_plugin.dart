import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/app_settings.dart';
import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Versión instalada y estado de notas de versión no leídas.
class WhatsNewWidgetPlugin extends FolioWidgetPlugin {
  const WhatsNewWidgetPlugin();

  @override
  String get id => 'whats_new';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetWhatsNew;

  @override
  IconData get icon => Icons.campaign_outlined;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      trailing: _UnreadBadge(appSettings: ctx.appSettings),
      child: _WhatsNewBody(appSettings: ctx.appSettings),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.appSettings});

  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final info = snap.data!;
        final versionLabel = _versionLabel(info);
        if (versionLabel.isEmpty) return const SizedBox.shrink();
        final lastSeen = appSettings.lastSeenReleaseNotesVersion.trim();
        final unread = lastSeen != versionLabel;
        if (!unread) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            AppLocalizations.of(context).widgetWhatsNewBadge,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

class _WhatsNewBody extends StatelessWidget {
  const _WhatsNewBody({required this.appSettings});

  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final l10n = AppLocalizations.of(context);
        final info = snap.data;
        if (info == null) {
          return BuiltinWidgetEmpty(
            message: l10n.widgetWhatsNewVersionError,
          );
        }
        final versionLabel = _versionLabel(info);
        if (versionLabel.isEmpty) {
          return BuiltinWidgetEmpty(
            message: l10n.widgetWhatsNewVersionError,
          );
        }
        final lastSeen = appSettings.lastSeenReleaseNotesVersion.trim();
        final unread = lastSeen != versionLabel;
        final scheme = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.widgetWhatsNewVersionLabel(versionLabel),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              unread
                  ? l10n.widgetWhatsNewUnread
                  : l10n.widgetWhatsNewUpToDate,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        );
      },
    );
  }
}

String _versionLabel(PackageInfo info) {
  final appVersion = info.version.trim();
  final buildNumber = info.buildNumber.trim();
  if (appVersion.isEmpty) return '';
  return buildNumber.isEmpty ? appVersion : '$appVersion+$buildNumber';
}
