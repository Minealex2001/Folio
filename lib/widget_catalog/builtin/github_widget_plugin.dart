import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

/// Estado de conexiones/repos GitHub ya guardados en la sesión (sin API).
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
    final connections = ctx.session.githubConnections;
    final sources = ctx.session.githubSources;

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: connections.isEmpty && sources.isEmpty
          ? const BuiltinWidgetEmpty(
              message:
                  'Conecta GitHub en Ajustes → Integraciones para ver repos aquí.',
            )
          : ListView(
              children: [
                if (connections.isNotEmpty) ...[
                  Text(
                    'Cuentas',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  for (final c in connections.take(4))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline_rounded, size: 18),
                      title: Text(
                        c.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Repositorios',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  for (final s in sources.take(8))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.book_outlined, size: 18),
                      title: Text(
                        '${s.owner}/${s.repo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: s.name.trim().isEmpty
                          ? null
                          : Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                ],
              ],
            ),
    );
  }
}
