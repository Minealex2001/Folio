import 'package:flutter/material.dart';

import '../../app/ui_tokens.dart';
import '../../l10n/generated/app_localizations.dart';
import 'folio_cloud_pitch_content.dart';

/// Pantalla breve con beneficios de Folio Cloud antes de registrarse o abrir checkout.
class FolioCloudSubscriptionPitchPage extends StatelessWidget {
  const FolioCloudSubscriptionPitchPage({
    super.key,
    required this.onPrimaryCta,
    required this.primaryCtaLabel,
    this.primaryIcon = Icons.subscriptions_outlined,
    this.busy = false,
    this.headlineOverride,
    this.highlightFeatureIndex = 0,
  });

  final VoidCallback onPrimaryCta;
  final String primaryCtaLabel;
  final IconData primaryIcon;
  final bool busy;
  final String? headlineOverride;
  final int highlightFeatureIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.folioCloudPitchScreenTitle),
      ),
      body: FolioCloudPitchBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              FolioSpace.md,
              FolioSpace.sm,
              FolioSpace.md,
              FolioSpace.xl,
            ),
            child: FolioCloudPitchContent(
              onPrimaryCta: onPrimaryCta,
              primaryCtaLabel: primaryCtaLabel,
              primaryIcon: primaryIcon,
              busy: busy,
              headlineOverride: headlineOverride,
              highlightFeatureIndex: highlightFeatureIndex,
            ),
          ),
        ),
      ),
    );
  }
}
