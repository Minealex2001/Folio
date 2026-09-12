import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Estado de la libreta activa (nombre, cifrado, páginas).
class VaultStatusWidgetPlugin extends FolioWidgetPlugin {
  const VaultStatusWidgetPlugin();

  @override
  String get id => 'vault_status';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetVaultStatus;

  @override
  IconData get icon => Icons.shield_outlined;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final l10n = AppLocalizations.of(context);
    final encrypted = ctx.session.vaultUsesEncryption;
    final pageCount = ctx.session.pages.where((p) => !p.isTrashed).length;
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: FutureBuilder<String>(
        future: ctx.session.getActiveVaultDisplayLabel(),
        builder: (context, snap) {
          final name = snap.data?.trim();
          final label = (name == null || name.isEmpty || name == '—')
              ? null
              : name;
          return Row(
            children: [
              Icon(
                encrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    ?label,
                    encrypted
                        ? l10n.widgetVaultStatusEncrypted
                        : l10n.widgetVaultStatusUnencrypted,
                    l10n.widgetVaultStatusPageCount(pageCount),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
