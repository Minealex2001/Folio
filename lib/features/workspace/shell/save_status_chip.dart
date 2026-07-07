import 'package:flutter/material.dart';

import '../../../application/vault_persistence_controller.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Indicador compacto del estado de guardado (no reconstruye el editor).
class SaveStatusChip extends StatelessWidget {
  const SaveStatusChip({
    super.key,
    required this.status,
    this.compact = true,
  });

  final SaveStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (status == SaveStatus.idle) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      SaveStatus.pending => (l10n.saveStatusPending, scheme.onSurfaceVariant),
      SaveStatus.saving => (l10n.saveStatusSaving, scheme.primary),
      SaveStatus.saved => (l10n.saveStatusSaved, scheme.tertiary),
      SaveStatus.error => (l10n.saveStatusError, scheme.error),
      SaveStatus.idle => (l10n.saveStatusIdle, scheme.onSurfaceVariant),
    };
    return Semantics(
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == SaveStatus.saving)
              SizedBox(
                width: compact ? 12 : 14,
                height: compact ? 12 : 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(
                status == SaveStatus.error
                    ? Icons.error_outline_rounded
                    : Icons.cloud_done_outlined,
                size: compact ? 14 : 16,
                color: color,
              ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
