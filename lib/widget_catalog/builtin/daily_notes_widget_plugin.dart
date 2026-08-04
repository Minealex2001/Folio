import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Nota diaria — Folio no tiene todavía un concepto de "nota diaria" formal
/// (sin campo dedicado en `FolioPage`), así que este plugin busca una
/// página cuyo título sea la fecha de hoy en formato ISO y, si no existe,
/// ofrece crearla honestamente en vez de simular una.
class DailyNotesWidgetPlugin extends FolioWidgetPlugin {
  const DailyNotesWidgetPlugin();

  @override
  String get id => 'daily_notes';

  @override
  String displayName(BuildContext context) => 'Nota diaria';

  @override
  IconData get icon => Icons.today_rounded;

  @override
  bool get allowMultipleInstances => false;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final today = _isoDate(DateTime.now());
    final existing = ctx.session.pages
        .where((p) => !p.isTrashed && p.title.trim() == today)
        .firstOrNull;

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: existing == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No hay nota para hoy ($today).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: ctx.onCreatePage,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Crear página'),
                ),
              ],
            )
          : ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(today),
              onTap: () => ctx.onSelectPage?.call(existing.id),
            ),
    );
  }
}
