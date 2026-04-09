import 'package:pub_semver/pub_semver.dart';

import '../../app/app_settings.dart';
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

  String toReportText() {
    return [
      'Folio release readiness',
      'Version instalada: $installedVersionLabel',
      'SemVer valido: ${isSemverValid ? 'si' : 'no'}',
      'Canal updates: ${updateReleaseChannel == UpdateReleaseChannel.beta ? 'beta' : 'stable'}',
      'Cofre activo: $activeVaultId',
      'Ruta cofre: $activeVaultPath',
      'Cofre desbloqueado: ${isVaultUnlocked ? 'si' : 'no'}',
      'Cofre cifrado: ${isVaultEncrypted ? 'si' : 'no'}',
      'IA habilitada: ${isAiEnabled ? 'si' : 'no'}',
      'Politica endpoint IA: ${isAiEndpointPolicyValid ? 'ok' : 'error'}',
      'Detalle IA: $aiSummary',
      'Estado release: ${isReadyForRelease ? 'ready' : 'blocked'}',
      'Bloqueadores pendientes: $failedBlockers',
      'Advertencias pendientes: $failedWarnings',
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
  var aiSummary = 'IA desactivada';
  if (isAiEnabled) {
    if (aiProvider == AiProvider.folioCloud) {
      aiPolicyOk = true;
      aiSummary = 'Folio Cloud IA (sin endpoint local)';
    } else {
      final issue = AiSafetyPolicy.validateEndpoint(
        rawUrl: aiBaseUrl,
        mode: aiEndpointMode,
        remoteConfirmed: aiRemoteEndpointConfirmed,
      );
      aiPolicyOk = issue == null;
      aiSummary = issue ?? 'Endpoint valido: $aiBaseUrl';
    }
  }

  final checks = <ReleaseCheckItem>[
    ReleaseCheckItem(
      id: 'semver',
      label: 'Version SemVer valida',
      ok: semverOk,
      severity: ReleaseCheckSeverity.blocker,
      details: semverOk ? null : 'La version instalada no cumple SemVer.',
    ),
    ReleaseCheckItem(
      id: 'vault_encrypted',
      label: 'Cofre cifrado',
      ok: isVaultEncrypted,
      severity: ReleaseCheckSeverity.blocker,
      details: isVaultEncrypted ? null : 'El cofre actual no esta cifrado.',
    ),
    ReleaseCheckItem(
      id: 'ai_policy',
      label: 'Politica endpoint IA',
      ok: aiPolicyOk,
      severity: ReleaseCheckSeverity.blocker,
      details: aiSummary,
    ),
    ReleaseCheckItem(
      id: 'vault_unlocked',
      label: 'Cofre desbloqueado',
      ok: isVaultUnlocked,
      severity: ReleaseCheckSeverity.warning,
      details: isVaultUnlocked
          ? null
          : 'Desbloquea el cofre para validar export/import y flujo real.',
    ),
    ReleaseCheckItem(
      id: 'channel',
      label: 'Canal estable seleccionado',
      ok: updateReleaseChannel == UpdateReleaseChannel.stable,
      severity: ReleaseCheckSeverity.warning,
      details: updateReleaseChannel == UpdateReleaseChannel.stable
          ? null
          : 'El canal beta esta activo para updates.',
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
