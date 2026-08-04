import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Migración 1:1 de `WorkspaceHomeSectionIds.vaultStatus` — estado real de
/// la libreta activa (cifrada o no, cuántas páginas contiene).
class VaultStatusWidgetPlugin extends FolioWidgetPlugin {
  const VaultStatusWidgetPlugin();

  @override
  String get id => 'vault_status';

  @override
  String displayName(BuildContext context) => 'Estado de la libreta';

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
    final encrypted = ctx.session.vaultUsesEncryption;
    final pageCount = ctx.session.pages.where((p) => !p.isTrashed).length;
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: Row(
        children: [
          Icon(
            encrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              encrypted
                  ? 'Libreta cifrada · $pageCount páginas'
                  : 'Libreta sin cifrar · $pageCount páginas',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
