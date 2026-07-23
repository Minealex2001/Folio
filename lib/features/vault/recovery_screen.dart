import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../session/vault_session.dart';

/// Pantalla mínima cuando la libreta activa no se puede leer.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({
    super.key,
    required this.session,
    required this.appSettings,
  });

  final VaultSession session;
  final AppSettings appSettings;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  var _busy = false;
  String? _status;
  var _hasPreMigration = false;

  @override
  void initState() {
    super.initState();
    _refreshPreMigrationFlag();
  }

  Future<void> _refreshPreMigrationFlag() async {
    final has = await widget.session.hasPreMigrationBackup();
    if (mounted) setState(() => _hasPreMigration = has);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _status = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refreshPreMigrationFlag();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 48, color: scheme.error),
                  const SizedBox(height: 16),
                  Text(
                    l10n.vaultRecoveryTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.vaultRecoveryBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _status!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_hasPreMigration) ...[
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final ok = await widget.session
                                  .restoreVaultFromPreMigrationBackup();
                              if (!ok && mounted) {
                                setState(
                                  () => _status =
                                      l10n.vaultRecoveryRestorePreMigrationFail,
                                );
                              }
                            }),
                      child: Text(l10n.vaultRecoveryRestorePreMigration),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final ok = await widget.session
                                .restoreVaultFromLocalBackup();
                            if (!ok && mounted) {
                              setState(
                                () => _status = l10n.vaultRecoveryRestoreBakFail,
                              );
                            }
                          }),
                    child: Text(l10n.vaultRecoveryRestoreBak),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy || kIsWeb
                        ? null
                        : () => _run(() async {
                            final picked = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const ['zip', 'tar', 'gz', 'tgz'],
                            );
                            final path = picked?.files.single.path;
                            if (path == null || path.isEmpty) return;
                            await widget.session.restoreFromBackupZip(path, '');
                          }),
                    child: Text(l10n.vaultRecoveryRestoreZip),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy || kIsWeb
                        ? null
                        : () => _run(() async {
                            final dir = await FilePicker.getDirectoryPath(
                              dialogTitle: l10n.vaultRecoveryExportEmergency,
                            );
                            if (dir == null || dir.isEmpty) return;
                            final name =
                                'folio_emergency_${DateTime.now().millisecondsSinceEpoch}.zip';
                            await widget.session.exportEmergencyBackupZip(
                              p.join(dir, name),
                            );
                            if (mounted) {
                              setState(
                                () => _status = l10n.vaultRecoveryExportOk(name),
                              );
                            }
                          }),
                    child: Text(l10n.vaultRecoveryExportEmergency),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final path =
                                await widget.session.activeVaultDataDirectoryPath();
                            if (path == null) return;
                            final uri = Uri.file(path);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          }),
                    child: Text(l10n.vaultRecoveryOpenDataFolder),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => widget.session.bootstrap(),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
