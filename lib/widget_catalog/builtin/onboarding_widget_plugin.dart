import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../../data/vault_paths.dart';
import '../../features/workspace/recent_page_visits.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Checklist de primeros pasos con datos reales de sesión y recientes.
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
    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: _OnboardingChecklist(ctx: ctx),
    );
  }
}

class _OnboardingChecklist extends StatefulWidget {
  const _OnboardingChecklist({required this.ctx});

  final WidgetPluginContext ctx;

  @override
  State<_OnboardingChecklist> createState() => _OnboardingChecklistState();
}

class _OnboardingChecklistState extends State<_OnboardingChecklist> {
  late final Future<bool> _visitedRecentsFuture = _loadVisitedRecents();

  Future<bool> _loadVisitedRecents() async {
    final visits = await RecentPageVisitsStore.load(
      vaultId: VaultPaths.activeVaultId,
      validPageIds: widget.ctx.session.pages.map((p) => p.id).toSet(),
      limit: 1,
    );
    return visits.isNotEmpty;
  }

  Widget _stepRow({
    required BuildContext context,
    required String label,
    required bool done,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 20,
          color: done ? scheme.primary : scheme.outlineVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: done ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: row);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ctx.session,
      builder: (context, _) {
        final hasPages = widget.ctx.session.pages.any((p) => !p.isTrashed);
        final hasTasks = widget.ctx.session.collectTaskBlocks().isNotEmpty;

        return FutureBuilder<bool>(
          future: _visitedRecentsFuture,
          builder: (context, snapshot) {
            final visitedRecents = snapshot.data ?? false;
            final allDone = hasPages && hasTasks && visitedRecents;

            if (allDone) {
              return const BuiltinWidgetEmpty(
                message: '¡Completaste los primeros pasos!',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Empieza con lo básico:',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                _stepRow(
                  context: context,
                  label: 'Crear una página',
                  done: hasPages,
                  onTap: hasPages ? null : widget.ctx.onCreatePage,
                ),
                _stepRow(
                  context: context,
                  label: 'Añadir una tarea',
                  done: hasTasks,
                ),
                _stepRow(
                  context: context,
                  label: 'Visitar una página reciente',
                  done: visitedRecents,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
