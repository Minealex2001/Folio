import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Migración 1:1 de `WorkspaceHomeSectionIds.onboarding` — versión reducida:
/// la tarjeta de onboarding legacy (`_buildOnboardingSection` en
/// `workspace_home_view.dart`) tiene lógica de pasos/estado propia de
/// `AppSettings` no expuesta en [WidgetPluginContext]; aquí se ofrece el
/// CTA real de "primer paso" (crear una página) usando la capacidad que sí
/// está disponible, en vez de simular pasos falsos.
class OnboardingWidgetPlugin extends FolioWidgetPlugin {
  const OnboardingWidgetPlugin();

  @override
  String get id => 'onboarding';

  @override
  String displayName(BuildContext context) => 'Primeros pasos';

  @override
  IconData get icon => Icons.flag_outlined;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final hasPages = ctx.session.pages.any((p) => !p.isTrashed);
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: hasPages
          ? const BuiltinWidgetComingSoon(message: '¡Ya diste tu primer paso!')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Crea tu primera página para empezar.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: ctx.onCreatePage,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Crear página'),
                ),
              ],
            ),
    );
  }
}
