import 'package:flutter/material.dart';

import '../../app/folio_distribution.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../l10n/generated/app_localizations.dart';
import 'folio_cloud_checkout.dart';
import 'folio_microsoft_store_channel.dart';
import 'folio_microsoft_store_products.dart';

/// Canal de pago elegido por el usuario (solo Windows).
enum FolioCloudPurchaseChannel {
  microsoftStore,
  stripeInBrowser,
}

bool _microsoftStoreProductConfigured(FolioCheckoutKind kind) {
  switch (kind) {
    case FolioCheckoutKind.folioCloudMonthly:
      return FolioMicrosoftStoreProducts.hasMonthlyProductId;
    case FolioCheckoutKind.inkSmall:
      return FolioMicrosoftStoreProducts.inkSmall.trim().isNotEmpty;
    case FolioCheckoutKind.inkMedium:
      return FolioMicrosoftStoreProducts.inkMedium.trim().isNotEmpty;
    case FolioCheckoutKind.inkLarge:
      return FolioMicrosoftStoreProducts.inkLarge.trim().isNotEmpty;
    case FolioCheckoutKind.backupStoragePackSmall:
      return FolioMicrosoftStoreProducts.backupStoragePackSmall.trim().isNotEmpty;
    case FolioCheckoutKind.backupStoragePackMedium:
      return FolioMicrosoftStoreProducts.backupStoragePackMedium.trim().isNotEmpty;
    case FolioCheckoutKind.backupStoragePackLarge:
      return FolioMicrosoftStoreProducts.backupStoragePackLarge.trim().isNotEmpty;
  }
}

/// En Windows muestra el selector Tienda / navegador. Devuelve [null] si cancela.
/// Fuera de Windows no debe llamarse (o se puede llamar y devolverá [null]).
///
/// Si [FolioDistribution.showMicrosoftStoreIntegration] es falso, no debe
/// llamarse; si se llama, devuelve [null] (equivalente a cancelar).
Future<FolioCloudPurchaseChannel?> showFolioCloudPurchaseChannelDialog(
  BuildContext context, {
  required FolioCheckoutKind checkoutKind,
}) async {
  if (!FolioMicrosoftStoreChannel.isRuntimeSupported) {
    return null;
  }
  if (!FolioDistribution.showMicrosoftStoreIntegration) {
    return null;
  }
  final l10n = AppLocalizations.of(context);
  final msReady = _microsoftStoreProductConfigured(checkoutKind);

  return showDialog<FolioCloudPurchaseChannel>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return FolioDialog(
        title: Text(l10n.folioCloudPurchaseChannelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.folioCloudPurchaseChannelBody,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
            if (!msReady) ...[
              const SizedBox(height: 10),
              Text(
                l10n.folioCloudPurchaseChannelStoreNotConfigured,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Builder(
              builder: (context) {
                final btn = FilledButton.icon(
                  onPressed: msReady
                      ? () => Navigator.pop(
                            ctx,
                            FolioCloudPurchaseChannel.microsoftStore,
                          )
                      : null,
                  icon: const Icon(Icons.shop_2_outlined, size: 22),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(l10n.folioCloudPurchaseChannelMicrosoftStore),
                  ),
                );
                if (msReady) return btn;
                return Tooltip(
                  message:
                      l10n.folioCloudPurchaseChannelStoreNotConfiguredHint,
                  child: btn,
                );
              },
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(
                ctx,
                FolioCloudPurchaseChannel.stripeInBrowser,
              ),
              icon: const Icon(Icons.open_in_browser_outlined, size: 22),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(l10n.folioCloudPurchaseChannelStripe),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.folioCloudPurchaseChannelCancel),
          ),
        ],
      );
    },
  );
}
