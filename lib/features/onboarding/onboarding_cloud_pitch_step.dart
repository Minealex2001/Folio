import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/folio_usage_intent.dart';
import '../../services/cloud_account/cloud_account_controller.dart';
import '../../services/folio_cloud/folio_cloud_conversion_flow.dart';
import '../../services/folio_cloud/folio_cloud_entitlements.dart';
import '../../services/folio_cloud/folio_cloud_pitch_helpers.dart';
import '../../services/folio_telemetry.dart';
import '../settings/folio_cloud_pitch_content.dart';

/// Paso de onboarding con pitch de Folio Cloud y embudo de conversión opcional.
class OnboardingCloudPitchStep extends StatefulWidget {
  const OnboardingCloudPitchStep({
    super.key,
    required this.cloud,
    required this.folio,
    required this.usageIntents,
    required this.onAuthError,
    required this.onContinue,
    required this.onBack,
    this.busy = false,
  });

  final CloudAccountController cloud;
  final FolioCloudEntitlementsController folio;
  final List<FolioUsageIntent> usageIntents;
  final String Function(String code) onAuthError;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final bool busy;

  @override
  State<OnboardingCloudPitchStep> createState() => _OnboardingCloudPitchStepState();
}

class _OnboardingCloudPitchStepState extends State<OnboardingCloudPitchStep> {
  var _actionBusy = false;

  FolioCloudConversionFlow get _conversion => FolioCloudConversionFlow(
        cloud: widget.cloud,
        folio: widget.folio,
      );

  FolioUsageIntent? get _primaryIntent =>
      widget.usageIntents.isNotEmpty ? widget.usageIntents.first : null;

  bool get _isBusy => widget.busy || _actionBusy;

  @override
  void initState() {
    super.initState();
    unawaited(
      FolioTelemetry.logOnboardingCloudPitchViewed(),
    );
  }

  String _primaryCtaLabel(AppLocalizations l10n) {
    final snap = widget.folio.snapshot;
    if (snap.active) return l10n.continueAction;
    if (widget.cloud.isSignedIn) return l10n.onboardingFolioCloudCtaSubscribe;
    return l10n.onboardingFolioCloudCtaCreateAccount;
  }

  IconData get _primaryIcon {
    final snap = widget.folio.snapshot;
    if (snap.active) return Icons.check_rounded;
    if (widget.cloud.isSignedIn) return Icons.subscriptions_outlined;
    return Icons.person_add_outlined;
  }

  Future<void> _onPrimary() async {
    if (_isBusy) return;
    final l10n = AppLocalizations.of(context);
    final snap = widget.folio.snapshot;
    if (snap.active) {
      widget.onContinue();
      return;
    }
    setState(() => _actionBusy = true);
    try {
      if (widget.cloud.isSignedIn) {
        unawaited(FolioTelemetry.logOnboardingCloudCheckoutTapped());
      } else {
        unawaited(FolioTelemetry.logOnboardingCloudSignInTapped());
      }
      final ok = await _conversion.runMonthlySubscriptionFunnel(
        context,
        l10n: l10n,
        onAuthError: widget.onAuthError,
      );
      if (!mounted) return;
      if (ok || widget.folio.snapshot.active) {
        widget.onContinue();
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _onSkip() {
    if (_isBusy) return;
    unawaited(FolioTelemetry.logOnboardingCloudSkipped());
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([widget.cloud, widget.folio]),
      builder: (context, _) {
        return SingleChildScrollView(
          child: FolioCloudPitchContent(
            embedded: true,
            busy: _isBusy,
            onPrimaryCta: () => unawaited(_onPrimary()),
            primaryCtaLabel: _primaryCtaLabel(l10n),
            primaryIcon: _primaryIcon,
            headlineOverride: folioCloudOnboardingPitchHeadline(
              l10n,
              _primaryIntent,
            ),
            highlightFeatureIndex: folioCloudHighlightFeatureIndex(
              _primaryIntent,
            ),
            onSkip: _onSkip,
            skipLabel: l10n.onboardingFolioCloudSkip,
          ),
        );
      },
    );
  }
}
