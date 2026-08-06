import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

List<String> _kTips(AppLocalizations l10n) => [
  l10n.widgetTipEditorSlash,
  l10n.widgetTipDragPage,
  l10n.widgetTipSearchShortcut,
  l10n.widgetTipVisualEditor,
  l10n.widgetTipTasksHome,
];

/// Migración 1:1 de `WorkspaceHomeSectionIds.tip` — rota entre consejos
/// reales de uso de Folio, determinístico por día del año (no aleatorio,
/// para no cambiar en cada rebuild).
class TipWidgetPlugin extends FolioWidgetPlugin {
  const TipWidgetPlugin();

  @override
  String get id => 'tip';

  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).widgetTip;

  @override
  IconData get icon => Icons.lightbulb_outline_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final dayOfYear = int.parse(
      DateTime.now().difference(DateTime(DateTime.now().year)).inDays
          .toString(),
    );
    final tips = _kTips(AppLocalizations.of(context));
    final tip = tips[dayOfYear % tips.length];
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: Text(tip, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
