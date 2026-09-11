import 'package:flutter/material.dart';

import '../../../app/widgets/folio_dialog.dart';
import '../../../app/widgets/folio_skeletons.dart';
<<<<<<< HEAD
=======
import '../../../l10n/generated/app_localizations.dart';
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
import '../../../services/admin/admin_settings_api.dart';

/// SUPER_ADMIN only — every write here can affect production behavior for every user, so this
/// section always shows a stronger confirmation than the rest of the console.
class AdminAppSettingsSection extends StatefulWidget {
  const AdminAppSettingsSection({super.key});

  @override
  State<AdminAppSettingsSection> createState() => _AdminAppSettingsSectionState();
}

class _AdminAppSettingsSectionState extends State<AdminAppSettingsSection> {
  final _api = const AdminSettingsApi();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _settings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _api.list();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _edit(Map<String, dynamic> setting) async {
<<<<<<< HEAD
=======
    final l10n = AppLocalizations.of(context);
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
    final key = setting['key']?.toString() ?? '';
    final controller = TextEditingController(text: setting['effectiveValue']?.toString() ?? '');
    final ok = await FolioDialog.confirm(
      context,
<<<<<<< HEAD
      title: Text('Editar $key'),
=======
      title: Text(l10n.adminEditSettingTitle(key)),
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              setting['description']?.toString() ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
<<<<<<< HEAD
              decoration: InputDecoration(labelText: 'Valor (${setting['valueType']})', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Text(
              'Esto puede afectar a la app en producción para todos los usuarios.',
=======
              decoration: InputDecoration(labelText: l10n.adminValueLabel(setting['valueType']), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.adminSettingWarningBody,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
<<<<<<< HEAD
      confirmLabel: 'Guardar',
=======
      confirmLabel: l10n.save,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
      destructive: true,
    );
    if (ok != true) return;
    try {
      await _api.update(key, controller.text.trim());
      await _load();
    } catch (e) {
      if (!mounted) return;
<<<<<<< HEAD
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
=======
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminErrorWithDetails('$e'))));
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
    }
  }

  Future<void> _clear(Map<String, dynamic> setting) async {
<<<<<<< HEAD
    final key = setting['key']?.toString() ?? '';
    final ok = await FolioDialog.confirm(
      context,
      title: Text('Quitar override de $key'),
      content: const Text('Volverá a usar el valor de application.yml/variables de entorno.'),
      confirmLabel: 'Quitar override',
=======
    final l10n = AppLocalizations.of(context);
    final key = setting['key']?.toString() ?? '';
    final ok = await FolioDialog.confirm(
      context,
      title: Text(l10n.adminClearOverrideTitle(key)),
      content: Text(l10n.adminClearOverrideBody),
      confirmLabel: l10n.adminActionClearOverride,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
      destructive: true,
    );
    if (ok != true) return;
    try {
      await _api.clear(key);
      await _load();
    } catch (e) {
      if (!mounted) return;
<<<<<<< HEAD
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
=======
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminErrorWithDetails('$e'))));
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
<<<<<<< HEAD
=======
    final l10n = AppLocalizations.of(context);
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
    if (_loading) return const Center(child: FolioLoadingIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: scheme.error)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _settings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final s = _settings[index];
          final overridden = s['overridden'] == true;
          return Card(
            child: ListTile(
              leading: Icon(
                overridden ? Icons.tune_rounded : Icons.settings_suggest_outlined,
                color: overridden ? scheme.primary : null,
              ),
              title: Text(s['key']?.toString() ?? ''),
              subtitle: Text(
                '${s['description'] ?? ''}\n'
<<<<<<< HEAD
                'valor actual: ${s['effectiveValue'] ?? '—'}${overridden ? ' (override)' : ' (por defecto)'}',
=======
                '${l10n.adminCurrentValueLabel}: ${s['effectiveValue'] ?? '—'} '
                '(${overridden ? l10n.adminOverrideSuffix : l10n.adminDefaultSuffix})',
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 4,
                children: [
                  if (overridden)
                    IconButton(
<<<<<<< HEAD
                      tooltip: 'Quitar override',
=======
                      tooltip: l10n.adminActionClearOverride,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
                      icon: const Icon(Icons.restore_rounded),
                      onPressed: () => _clear(s),
                    ),
                  IconButton(
<<<<<<< HEAD
                    tooltip: 'Editar',
=======
                    tooltip: l10n.adminActionEdit,
>>>>>>> 6a0aa5e40f4e97ec3a7dc4005e3d074cd104d623
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(s),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
