import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_settings.dart';
import '../../../../app/ui_tokens.dart';
import '../../../../app/widgets/folio_dialog.dart';
import '../../../../app/widgets/folio_feedback.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/media/media_playback_router.dart';
import '../../../../services/platform/pwa_install.dart';
import '../../../../session/vault_session.dart';
import '../../widgets/spotify_now_playing_bar.dart';
import '../page_trash_sheet.dart';

class SidebarFooter extends StatelessWidget {
  const SidebarFooter({
    super.key,
    required this.session,
    required this.appSettings,
    required this.trashCount,
    this.onOpenSettings,
    required this.onSpotifyExpandedChanged,
  });

  final VaultSession session;
  final AppSettings appSettings;
  final int trashCount;
  final VoidCallback? onOpenSettings;
  final VoidCallback onSpotifyExpandedChanged;

  Future<void> _installWebApp(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final outcome = await PwaInstallController.instance.promptInstall();
    if (!context.mounted) return;
    switch (outcome) {
      case PwaInstallOutcome.accepted:
        showFolioSnack(context, l10n.installWebAppDone);
      case PwaInstallOutcome.dismissed:
        showFolioSnack(context, l10n.installWebAppDismissed);
      case PwaInstallOutcome.unavailable:
        await _showInstallWebAppHowTo(context);
    }
  }

  Future<void> _showInstallWebAppHowTo(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await FolioDialog.info(
      context,
      title: Text(l10n.installWebAppHowToTitle),
      content: Text(l10n.installWebAppHowToBody),
      okLabel: l10n.ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FolioSpace.sm,
              0,
              FolioSpace.sm,
              FolioSpace.xs,
            ),
            child: ListenableBuilder(
              listenable: PwaInstallController.instance,
              builder: (context, _) {
                final pwa = PwaInstallController.instance;
                if (pwa.isStandalone) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pwa.canInstall)
                      Padding(
                        padding: const EdgeInsets.only(bottom: FolioSpace.xs),
                        child: FilledButton.icon(
                          onPressed: () => unawaited(_installWebApp(context)),
                          icon: const Icon(Icons.install_desktop_rounded),
                          label: Text(l10n.installWebApp),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: FolioSpace.xs),
                        child: FilledButton.tonalIcon(
                          onPressed: () => unawaited(_showInstallWebAppHowTo(context)),
                          icon: const Icon(Icons.add_to_home_screen_rounded),
                          label: Text(l10n.installWebApp),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://minealexgames.com/folio'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(l10n.downloadDesktopApp),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            FolioSpace.sm,
            0,
            FolioSpace.sm,
            onOpenSettings != null ? FolioSpace.xs : FolioSpace.sm,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.sidebarTrashTitle,
                onPressed: () => unawaited(
                  showPageTrashSheet(context: context, session: session),
                ),
                icon: Badge(
                  isLabelVisible: trashCount > 0,
                  label: Text(
                    l10n.sidebarTrashCountBadge(trashCount),
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded),
                ),
              ),
              if (onOpenSettings != null) ...[
                const SizedBox(width: FolioSpace.xs),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: Text(l10n.settings),
                  ),
                ),
              ],
            ],
          ),
        ),
        ListenableBuilder(
          listenable: MediaPlaybackRouter.instance,
          builder: (context, _) {
            if (!MediaPlaybackRouter.instance.shouldShowBar) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                FolioSpace.sm,
                0,
                FolioSpace.sm,
                FolioSpace.sm,
              ),
              child: SpotifyNowPlayingBar(
                session: session,
                density: appSettings.workspaceSidebarSpotifyExpanded
                    ? SpotifyBarDensity.expanded
                    : SpotifyBarDensity.mini,
                onToggleExpanded: () {
                  final next = !appSettings.workspaceSidebarSpotifyExpanded;
                  unawaited(
                    appSettings.setWorkspaceSidebarSpotifyExpanded(next),
                  );
                  onSpotifyExpandedChanged();
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
