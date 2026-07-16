import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/folio_cloud_pack_format.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/vault_cloud_pack_progress.dart';

/// Solo barra de progreso; mensajes van a consola con [logConsole].
class VaultBackupProgressController extends ChangeNotifier {
  VaultBackupProgressController();

  double progress = 0;
  bool indeterminate = false;

  void setProgress(double p01, {bool indeterminate = false}) {
    progress = p01.clamp(0.0, 1.0);
    this.indeterminate = indeterminate;
    notifyListeners();
  }

  /// Registro para desarrollo / depuración (no se muestra en la UI).
  static void logConsole(String line) {
    debugPrint('[Folio backup] $line');
  }
}

String cloudPackProgressLogLine(AppLocalizations l10n, VaultCloudPackProgress u) {
  String blobLabel(FolioCloudPackBlobRole? r) {
    if (r == null) return '';
    switch (r) {
      case FolioCloudPackBlobRole.backupManifest:
        return l10n.vaultCloudPackProgressBlobManifest;
      case FolioCloudPackBlobRole.vaultKeys:
        return l10n.vaultCloudPackProgressBlobVaultKeys;
      case FolioCloudPackBlobRole.vaultBin:
        return l10n.vaultCloudPackProgressBlobVaultData;
      case FolioCloudPackBlobRole.vaultMode:
        return l10n.vaultCloudPackProgressBlobVaultMode;
      case FolioCloudPackBlobRole.attachment:
        final name = u.attachmentRelativePath ?? '';
        return name.isEmpty
            ? l10n.vaultCloudPackProgressBlobAttachmentAnonymous
            : l10n.vaultCloudPackProgressBlobAttachment(name);
    }
  }

  switch (u.step) {
    case VaultCloudPackProgressStep.preparing:
      return l10n.vaultCloudPackProgressPreparing;
    case VaultCloudPackProgressStep.persisting:
      return l10n.vaultCloudPackProgressPersisting;
    case VaultCloudPackProgressStep.fingerprinting:
      return l10n.vaultCloudPackProgressFingerprint;
    case VaultCloudPackProgressStep.fetchingMeta:
      return l10n.vaultCloudPackProgressFetchingMeta;
    case VaultCloudPackProgressStep.skippedUpToDate:
      return l10n.vaultCloudPackProgressSkippedUpToDate;
    case VaultCloudPackProgressStep.restoreWrap:
      return l10n.vaultCloudPackProgressRestoreWrap;
    case VaultCloudPackProgressStep.indexingLocal:
      return l10n.vaultCloudPackProgressIndexingLocal;
    case VaultCloudPackProgressStep.downloadingPreviousManifest:
      return l10n.vaultCloudPackProgressDownloadingManifest;
    case VaultCloudPackProgressStep.uploadingBlob:
      final b = u.blobsCompleted ?? 0;
      final tot = u.blobsTotal ?? 0;
      final part = blobLabel(u.blobRole);
      if (tot > 0) {
        return l10n.vaultCloudPackProgressUploadingBlobProgress(b, tot, part);
      }
      return part;
    case VaultCloudPackProgressStep.uploadingSnapshot:
      return l10n.vaultCloudPackProgressUploadingSnapshot;
    case VaultCloudPackProgressStep.finalizing:
      return l10n.vaultCloudPackProgressFinalizing;
    case VaultCloudPackProgressStep.cleaningOldBlobs:
      return l10n.vaultCloudPackProgressCleaningBlobs;
    case VaultCloudPackProgressStep.updatingVaultIndex:
      return l10n.vaultCloudPackProgressUpdatingIndex;
    case VaultCloudPackProgressStep.complete:
      return l10n.vaultCloudPackProgressComplete;
  }
}

void _finishOverlay(
  OverlayEntry entry,
  Completer<void> completer, {
  Object? error,
  StackTrace? stackTrace,
}) {
  void close() {
    if (completer.isCompleted) return;
    entry.remove();
    if (error != null) {
      completer.completeError(error, stackTrace ?? StackTrace.empty);
    } else {
      completer.complete();
    }
  }

  SchedulerBinding.instance.addPostFrameCallback((_) => close());
}

OverlayState? _resolveOverlay(BuildContext context) {
  return Overlay.maybeOf(context) ??
      Navigator.maybeOf(context, rootNavigator: true)?.overlay;
}

/// Tarjeta flotante inferior (no modal): la app sigue siendo usable.
/// [work] se lanza una sola vez al montar el overlay.
Future<void> showVaultBackupProgressDialog({
  required BuildContext context,
  required AppLocalizations l10n,
  required Future<void> Function(VaultBackupProgressController ctrl) work,
}) async {
  final ctrl = VaultBackupProgressController();
  final completer = Completer<void>();

  if (!context.mounted) return;

  final overlayState = _resolveOverlay(context);
  if (overlayState == null) {
    try {
      await work(ctrl);
      return;
    } catch (e, st) {
      debugPrint('Vault backup error: $e\n$st');
      rethrow;
    }
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      final bottomInset = MediaQuery.paddingOf(overlayContext).bottom;
      return Positioned(
        left: 40,
        right: 40,
        bottom: 8 + bottomInset,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Material(
              elevation: 4,
              surfaceTintColor:
                  Theme.of(overlayContext).colorScheme.surfaceTint,
              color:
                  Theme.of(overlayContext).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: _VaultBackupProgressOverlayBody(
            l10n: l10n,
            controller: ctrl,
            work: work,
                onFinished: (Object? error, StackTrace? st) {
                  _finishOverlay(entry, completer,
                      error: error, stackTrace: st);
                },
              ),
            ),
          ),
        ),
      );
    },
  );

  overlayState.insert(entry);

  return completer.future;
}

class _VaultBackupProgressOverlayBody extends StatefulWidget {
  const _VaultBackupProgressOverlayBody({
    required this.l10n,
    required this.controller,
    required this.work,
    required this.onFinished,
  });

  final AppLocalizations l10n;
  final VaultBackupProgressController controller;
  final Future<void> Function(VaultBackupProgressController ctrl) work;
  final void Function(Object? error, StackTrace? stackTrace) onFinished;

  @override
  State<_VaultBackupProgressOverlayBody> createState() =>
      _VaultBackupProgressOverlayBodyState();
}

class _VaultBackupProgressOverlayBodyState
    extends State<_VaultBackupProgressOverlayBody> {
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) return;
      _started = true;
      _run();
    });
  }

  Future<void> _run() async {
    try {
      await widget.work(widget.controller);
      if (!mounted) return;
      widget.onFinished(null, null);
    } catch (e, st) {
      debugPrint('Vault backup error: $e\n$st');
      if (!mounted) return;
      widget.onFinished(e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.l10n.vaultBackupProgressDialogTitle,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 3,
                  child: widget.controller.indeterminate
                      ? const LinearProgressIndicator()
                      : LinearProgressIndicator(
                          value: widget.controller.progress,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
