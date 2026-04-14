import 'package:flutter_test/flutter_test.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/settings/release_readiness.dart';
import 'package:folio/l10n/generated/app_localizations_en.dart';
import 'package:folio/services/updater/update_release_channel.dart';

void main() {
  group('release readiness evaluator', () {
    test('accepts valid semver and localhost AI endpoint', () {
      final snapshot = evaluateReleaseReadiness(
        l10n: AppLocalizationsEn(),
        installedVersionLabel: '1.2.3+4',
        updateReleaseChannel: UpdateReleaseChannel.stable,
        activeVaultId: 'vault-1',
        activeVaultPath: r'C:\vaults\vault-1',
        isVaultUnlocked: true,
        isVaultEncrypted: true,
        isAiEnabled: true,
        aiProvider: AiProvider.ollama,
        aiBaseUrl: 'http://127.0.0.1:11434',
        aiEndpointMode: AiEndpointMode.localhostOnly,
        aiRemoteEndpointConfirmed: false,
      );

      expect(snapshot.isSemverValid, isTrue);
      expect(snapshot.isAiEndpointPolicyValid, isTrue);
      expect(snapshot.isReadyForRelease, isTrue);
      expect(snapshot.failedBlockers, 0);
      final report = snapshot.toReportText(AppLocalizationsEn());
      expect(report, isNotEmpty);
    });

    test('fails AI endpoint policy for unconfirmed remote endpoint', () {
      final snapshot = evaluateReleaseReadiness(
        l10n: AppLocalizationsEn(),
        installedVersionLabel: '0.0.1+1',
        updateReleaseChannel: UpdateReleaseChannel.beta,
        activeVaultId: 'vault-2',
        activeVaultPath: '/vaults/vault-2',
        isVaultUnlocked: true,
        isVaultEncrypted: true,
        isAiEnabled: true,
        aiProvider: AiProvider.ollama,
        aiBaseUrl: 'https://example.com',
        aiEndpointMode: AiEndpointMode.allowRemote,
        aiRemoteEndpointConfirmed: false,
      );

      expect(snapshot.isSemverValid, isTrue);
      expect(snapshot.isAiEndpointPolicyValid, isFalse);
      expect(snapshot.isReadyForRelease, isFalse);
      expect(snapshot.failedBlockers, greaterThan(0));
      final report = snapshot.toReportText(AppLocalizationsEn());
      expect(report, isNotEmpty);
    });

    test('marks invalid semver label', () {
      final snapshot = evaluateReleaseReadiness(
        l10n: AppLocalizationsEn(),
        installedVersionLabel: 'desconocida',
        updateReleaseChannel: UpdateReleaseChannel.stable,
        activeVaultId: null,
        activeVaultPath: null,
        isVaultUnlocked: false,
        isVaultEncrypted: false,
        isAiEnabled: false,
        aiProvider: AiProvider.none,
        aiBaseUrl: '',
        aiEndpointMode: AiEndpointMode.localhostOnly,
        aiRemoteEndpointConfirmed: false,
      );

      expect(snapshot.isSemverValid, isFalse);
      expect(snapshot.activeVaultId, '-');
      expect(snapshot.activeVaultPath, '-');
      expect(snapshot.isReadyForRelease, isFalse);
      final report = snapshot.toReportText(AppLocalizationsEn());
      expect(report, isNotEmpty);
    });

    test('beta channel is warning and not a blocker', () {
      final snapshot = evaluateReleaseReadiness(
        l10n: AppLocalizationsEn(),
        installedVersionLabel: '1.0.0+7',
        updateReleaseChannel: UpdateReleaseChannel.beta,
        activeVaultId: 'vault-3',
        activeVaultPath: '/vaults/vault-3',
        isVaultUnlocked: true,
        isVaultEncrypted: true,
        isAiEnabled: false,
        aiProvider: AiProvider.none,
        aiBaseUrl: '',
        aiEndpointMode: AiEndpointMode.localhostOnly,
        aiRemoteEndpointConfirmed: false,
      );

      expect(snapshot.failedBlockers, 0);
      expect(snapshot.failedWarnings, greaterThanOrEqualTo(1));
      expect(snapshot.isReadyForRelease, isTrue);
    });
  });

  test('builds deterministic release readiness report file name', () {
    final fileName = buildReleaseReadinessFileName(DateTime(2026, 3, 25, 9, 7));
    expect(fileName, 'folio-release-readiness-20260325_0907.txt');
  });
}
