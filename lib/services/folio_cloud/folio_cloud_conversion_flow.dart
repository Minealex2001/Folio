import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/folio_distribution.dart';
import '../../app/widgets/folio_dialog.dart';
import '../../app/widgets/folio_in_app_checkout_dialog.dart';
import '../../features/onboarding/cloud_sign_in_dialog.dart';
import '../../l10n/generated/app_localizations.dart';
import '../cloud_account/cloud_account_controller.dart';
import 'folio_cloud_checkout.dart';
import 'folio_cloud_entitlements.dart';
import 'folio_cloud_reachability.dart';

/// Flujo compartido de conversión Folio Cloud (sign-in + checkout).
class FolioCloudConversionFlow {
  FolioCloudConversionFlow({
    required this.cloud,
    required this.folio,
  });

  final CloudAccountController cloud;
  final FolioCloudEntitlementsController folio;

  Future<bool> ensureReachable(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final ok = await folioGoogleApisReachable();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cloudAuthErrorNetwork)),
        );
      }
      return ok;
    }
    return true;
  }

  Future<bool> signInIfNeeded(
    BuildContext context, {
    required AppLocalizations l10n,
    required String Function(String code) onAuthError,
  }) async {
    if (cloud.isSignedIn) return true;
    if (!await ensureReachable(context, l10n)) return false;
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CloudSignInDialog(
        l10n: l10n,
        cloud: cloud,
        onAuthError: onAuthError,
      ),
    );
    return ok == true && cloud.isSignedIn;
  }

  Future<bool> openMonthlyCheckout(
    BuildContext context, {
    required AppLocalizations l10n,
  }) async {
    // Google Play exige Google Play Billing para suscripciones digitales
    // compradas dentro de la app; no podemos abrir el checkout de Stripe
    // aquí. El inicio de sesión (arriba en runMonthlySubscriptionFunnel)
    // sigue disponible para cuentas ya suscritas desde otra plataforma.
    if (FolioDistribution.isPlayStore) {
      await FolioDialog.info(
        context,
        title: Text(l10n.folioCloudPlayStoreCheckoutUnavailableTitle),
        content: Text(l10n.folioCloudPlayStoreCheckoutUnavailableBody),
      );
      return false;
    }
    final uri = await createFolioCheckoutUri(FolioCheckoutKind.folioCloudMonthly);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsStripeCheckoutUnavailable)),
        );
      }
      return false;
    }
    if (!context.mounted) return false;
    if (FolioInAppCheckoutDialog.isSupported) {
      final success = await showDialog<bool>(
        context: context,
        builder: (ctx) => FolioInAppCheckoutDialog(
          url: uri.toString(),
          scheme: Theme.of(context).colorScheme,
        ),
      );
      if (success == true) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.folioCloudCheckoutSuccess)),
          );
        }
        await folio.refreshFolioCloudBillingFromServers();
        return true;
      }
      return false;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsCouldNotOpenLink)),
      );
    } else {
      folio.scheduleStripeSyncOnNextResume();
    }
    return ok;
  }

  /// Sign-in (si hace falta) y checkout mensual. Devuelve true si hay plan activo.
  Future<bool> runMonthlySubscriptionFunnel(
    BuildContext context, {
    required AppLocalizations l10n,
    required String Function(String code) onAuthError,
  }) async {
    if (folio.snapshot.active) return true;
    final signedIn = await signInIfNeeded(
      context,
      l10n: l10n,
      onAuthError: onAuthError,
    );
    if (!signedIn || !context.mounted) return false;
    if (folio.snapshot.active) return true;
    return openMonthlyCheckout(context, l10n: l10n);
  }
}
