import 'package:flutter/material.dart';

import '../../config/models/widget_instance_config.dart';
import '../folio_widget_plugin.dart';
import '../widget_plugin_context.dart';
import 'builtin_widget_card.dart';

int _intSetting(Map<String, dynamic> settings, String key, int defaultValue) {
  final raw = settings[key];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return defaultValue;
}

/// Migración 1:1 de `WorkspaceHomeSectionIds.rootPages` — páginas de nivel
/// raíz (`parentId == null`) de la libreta activa, vía `VaultSession.pages`.
class RootPagesWidgetPlugin extends FolioWidgetPlugin {
  const RootPagesWidgetPlugin();

  @override
  String get id => 'root_pages';

  @override
  String displayName(BuildContext context) => 'Páginas';

  @override
  IconData get icon => Icons.description_outlined;

  @override
  Widget build(
    BuildContext context,
    WidgetInstanceConfig instance,
    WidgetPluginContext ctx,
  ) {
    final maxCount = _intSetting(instance.settings, 'maxCount', 10);
    final roots = ctx.session.pages
        .where((p) => p.parentId == null && !p.isTrashed)
        .toList()
      ..sort(
        (a, b) => (a.title.isEmpty ? 'Sin título' : a.title)
            .toLowerCase()
            .compareTo(
              (b.title.isEmpty ? 'Sin título' : b.title).toLowerCase(),
            ),
      );
    final shown = roots.take(maxCount).toList();

    return BuiltinWidgetCard(
      icon: icon,
      title: displayName(context),
      child: shown.isEmpty
          ? const BuiltinWidgetEmpty(message: 'No hay páginas todavía.')
          : ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final page = shown[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: page.emoji != null && page.emoji!.isNotEmpty
                      ? Text(page.emoji!, style: const TextStyle(fontSize: 16))
                      : Icon(
                          page.isFolder
                              ? Icons.folder_outlined
                              : Icons.description_outlined,
                          size: 18,
                        ),
                  title: Text(
                    page.title.isEmpty ? 'Sin título' : page.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => ctx.onSelectPage?.call(page.id),
                );
              },
            ),
    );
  }

  @override
  Widget? buildSettings(
    BuildContext context,
    WidgetInstanceConfig instance,
    ValueChanged<Map<String, dynamic>> onSettingsChanged,
  ) {
    final settings = Map<String, dynamic>.from(instance.settings);
    final controller = TextEditingController(
      text: _intSetting(instance.settings, 'maxCount', 10).toString(),
    );
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Máximo de páginas',
        hintText: '10',
      ),
      onChanged: (v) {
        final n = int.tryParse(v.trim());
        if (n == null || n < 1) return;
        settings['maxCount'] = n;
        onSettingsChanged({...settings});
      },
    );
  }
}
