import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// GitHub — `lib/services/github/` existe pero expone flujos de auth/API
/// que requieren un controller propio no incluido en [WidgetPluginContext].
/// Conectar esta tarjeta a datos reales de PRs/issues es trabajo de una
/// fase futura (extender la superficie de capacidad del catálogo); por
/// ahora se declara honestamente en vez de simular actividad de GitHub.
class GithubWidgetPlugin extends FolioWidgetPlugin {
  const GithubWidgetPlugin();

  @override
  String get id => 'github';

  @override
  String displayName(BuildContext context) => 'GitHub';

  @override
  IconData get icon => Icons.code_rounded;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: const BuiltinWidgetComingSoon(
        message: 'Conecta tu cuenta de GitHub desde Ajustes para ver tu '
            'actividad aquí.',
      ),
    );
  }
}
