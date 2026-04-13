import 'package:pub_semver/pub_semver.dart';

import '../../app/app_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/ai/ai_safety_policy.dart';
import '../../services/updater/update_release_channel.dart';

enum ReleaseCheckSeverity { blocker, warning }

class ReleaseCheckItem {
  const ReleaseCheckItem({
    required this.id,
    required this.label,
    required this.ok,
    required this.severity,
    this.details,
  });

  final String id;
  final String label;
  final bool ok;
  final ReleaseCheckSeverity severity;
  final String? details;
}

class ReleaseReadinessSnapshot {
  const ReleaseReadinessSnapshot({
    required this.installedVersionLabel,
    required this.isSemverValid,
    required this.updateReleaseChannel,
    required this.activeVaultId,
    required this.activeVaultPath,
    required this.isVaultUnlocked,
    required this.isVaultEncrypted,
    required this.isAiEnabled,
    required this.isAiEndpointPolicyValid,
    required this.aiSummary,
    required this.checks,
  });

  final String installedVersionLabel;
  final bool isSemverValid;
  final UpdateReleaseChannel updateReleaseChannel;
  final String activeVaultId;
  final String activeVaultPath;
  final bool isVaultUnlocked;
  final bool isVaultEncrypted;
  final bool isAiEnabled;
  final bool isAiEndpointPolicyValid;
  final String aiSummary;
  final List<ReleaseCheckItem> checks;

  bool get isReadyForRelease => checks
      .where((c) => c.severity == ReleaseCheckSeverity.blocker)
      .every((c) => c.ok);

  int get failedBlockers => checks
      .where((c) => c.severity == ReleaseCheckSeverity.blocker && !c.ok)
      .length;

  int get failedWarnings => checks
      .where((c) => c.severity == ReleaseCheckSeverity.warning && !c.ok)
      .length;

  String toReportText(AppLocalizations l10n) {
    final y = l10n.releaseReadinessExportWordYes;
    final n = l10n.releaseReadinessExportWordNo;
    final channelLabel = updateReleaseChannel == UpdateReleaseChannel.beta
        ? l10n.releaseReadinessChannelBeta
        : l10n.releaseReadinessChannelStable;
    final statusLabel = isReadyForRelease
        ? l10n.releaseReadinessStatusReady
        : l10n.releaseReadinessStatusBlocked;
    final policyLine = isAiEndpointPolicyValid
        ? l10n.releaseReadinessPolicyOk
        : l10n.releaseReadinessPolicyError;
    return [
      l10n.releaseReadinessReportTitle,
      l10n.releaseReadinessReportInstalledVersion(installedVersionLabel),
      l10n.releaseReadinessReportSemver(isSemverValid ? y : n),
      l10n.releaseReadinessReportChannel(channelLabel),
      l10n.releaseReadinessReportActiveVault(activeVaultId),
      l10n.releaseReadinessReportVaultPath(activeVaultPath),
      l10n.releaseReadinessReportUnlocked(isVaultUnlocked ? y : n),
      l10n.releaseReadinessReportEncrypted(isVaultEncrypted ? y : n),
      l10n.releaseReadinessReportAiEnabled(isAiEnabled ? y : n),
      l10n.releaseReadinessReportAiPolicy(policyLine),
      l10n.releaseReadinessReportAiDetail(aiSummary),
      l10n.releaseReadinessReportStatus(statusLabel),
      l10n.releaseReadinessReportBlockers(failedBlockers),
      l10n.releaseReadinessReportWarnings(failedWarnings),
    ].join('\n');
  }
}

String buildReleaseReadinessFileName(DateTime now) {
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  return 'folio-release-readiness-$y$m${d}_$hh$mm.txt';
}

ReleaseReadinessSnapshot evaluateReleaseReadiness({
  required AppLocalizations l10n,
  required String installedVersionLabel,
  required UpdateReleaseChannel updateReleaseChannel,
  required String? activeVaultId,
  required String? activeVaultPath,
  required bool isVaultUnlocked,
  required bool isVaultEncrypted,
  required bool isAiEnabled,
  required AiProvider aiProvider,
  required String aiBaseUrl,
  required AiEndpointMode aiEndpointMode,
  required bool aiRemoteEndpointConfirmed,
}) {
  final versionCore = installedVersionLabel.split('+').first.trim();
  var semverOk = false;
  try {
    if (versionCore.isNotEmpty && versionCore != '...') {
      Version.parse(versionCore);
      semverOk = true;
    }
  } catch (_) {
    semverOk = false;
  }

  var aiPolicyOk = true;
  var aiSummary = l10n.releaseReadinessAiSummaryDisabled;
  if (isAiEnabled) {
    if (aiProvider == AiProvider.quillCloud) {
      aiPolicyOk = true;
      aiSummary = l10n.releaseReadinessAiSummaryQuillCloud;
    } else {
      final issue = AiSafetyPolicy.validateEndpointIssue(
        rawUrl: aiBaseUrl,
        mode: aiEndpointMode,
        remoteConfirmed: aiRemoteEndpointConfirmed,
      );
      aiPolicyOk = issue == null;
      aiSummary = issue != null
          ? issue.localizedMessage(l10n)
          : l10n.releaseReadinessAiSummaryEndpointOk(aiBaseUrl);
    }
  }

  final checks = <ReleaseCheckItem>[
    ReleaseCheckItem(
      id: 'semver',
      label: l10n.releaseReadinessSemverOk,
      ok: semverOk,
      severity: ReleaseCheckSeverity.blocker,
      details: semverOk ? null : l10n.releaseReadinessDetailSemverInvalid,
    ),
    ReleaseCheckItem(
      id: 'vault_encrypted',
      label: l10n.releaseReadinessEncryptedVault,
      ok: isVaultEncrypted,
      severity: ReleaseCheckSeverity.blocker,
      details: isVaultEncrypted
          ? null
          : l10n.releaseReadinessDetailVaultNotEncrypted,
    ),
    ReleaseCheckItem(
      id: 'ai_policy',
      label: l10n.releaseReadinessAiRemotePolicy,
      ok: aiPolicyOk,
      severity: ReleaseCheckSeverity.blocker,
      details: aiSummary,
    ),
    ReleaseCheckItem(
      id: 'vault_unlocked',
      label: l10n.releaseReadinessVaultUnlocked,
      ok: isVaultUnlocked,
      severity: ReleaseCheckSeverity.warning,
      details: isVaultUnlocked ? null : l10n.releaseReadinessDetailVaultLocked,
    ),
    ReleaseCheckItem(
      id: 'channel',
      label: l10n.releaseReadinessStableChannel,
      ok: updateReleaseChannel == UpdateReleaseChannel.stable,
      severity: ReleaseCheckSeverity.warning,
      details: updateReleaseChannel == UpdateReleaseChannel.stable
          ? null
          : l10n.releaseReadinessDetailBetaChannel,
    ),
  ];

  return ReleaseReadinessSnapshot(
    installedVersionLabel: installedVersionLabel,
    isSemverValid: semverOk,
    updateReleaseChannel: updateReleaseChannel,
    activeVaultId: (activeVaultId == null || activeVaultId.isEmpty)
        ? '-'
        : activeVaultId,
    activeVaultPath: (activeVaultPath == null || activeVaultPath.isEmpty)
        ? '-'
        : activeVaultPath,
    isVaultUnlocked: isVaultUnlocked,
    isVaultEncrypted: isVaultEncrypted,
    isAiEnabled: isAiEnabled,
    isAiEndpointPolicyValid: aiPolicyOk,
    aiSummary: aiSummary,
    checks: checks,
  );
}
