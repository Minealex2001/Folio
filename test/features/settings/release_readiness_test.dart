import 'package:flutter_test/flutter_test.dart';

import 'package:folio/app/app_settings.dart';
import 'package:folio/features/settings/release_readiness.dart';
import 'package:folio/services/updater/update_release_channel.dart';

void main() {
  group('release readiness evaluator', () {
    test('accepts valid semver and localhost AI endpoint', () {
      final snapshot = evaluateReleaseReadiness(
        installedVersionLabel: '1.2.3+4',
        updateReleaseChannel: UpdateReleaseChannel.stable,
        activeVaultId: 'vault-1',
        activeVaultPath: r'C:\vaults\vault-1',
        isVaultUnlocked: true,
        isVaultEncrypted: true,
        isAiEnabled: true,
        aiBaseUrl: 'http://127.0.0.1:11434',
        aiEndpointMode: AiEndpointMode.localhostOnly,
        aiRemoteEndpointConfirmed: false,
      );

      expect(snapshot.isSemverValid, isTrue);
      expect(snapshot.isAiEndpointPolicyValid, isTrue);
      expect(snapshot.isReadyForRelease, isTrue);
      expect(snapshot.failedBlockers, 0);
      expect(snapshot.toReportText(), contains('SemVer valido: si'));
      expect(snapshot.toReportText(), contains('Politica endpoint IA: ok'));
      expect(snapshot.toReportText(), contains('Estado release: ready'));
    });

    test('fails AI endpoint policy for unconfirmed remote endpoint', () {
      final snapshot = evaluateReleaseReadiness(
        installedVersionLabel: '0.0.1+1',
        updateReleaseChannel: UpdateReleaseChannel.beta,
        activeVaultId: 'vault-2',
        activeVaultPath: '/vaults/vault-2',
        isVaultUnlocked: true,
        isVaultEncrypted: true,
        isAiEnabled: true,
        aiBaseUrl: 'https://example.com',
        aiEndpointMode: AiEndpointMode.allowRemote,
        aiRemoteEndpointConfirmed: false,
      );

      expect(snapshot.isSemverValid, isTrue);
      expect(snapshot.isAiEndpointPolicyValid, isFalse);
      expect(snapshot.isReadyForRelease, isFalse);
      expect(snapshot.failedBlockers, greaterThan(0));
      expect(snapshot.toReportText(), contains('Canal updates: beta'));
      expect(snapshot.toReportText(), contains('Politica endpoint IA: error'));
      expect(snapshot.toReportText(), contains('Estado release: blocked'));
    });

    test('marks invalid semver label', () {
      final snapshot = evaluateReleaseReadiness(
        installedVersionLabel: 'desconocida',
        updateReleaseChannel: UpdateReleaseChannel.stable,
        activeVaultId: null,
        activeVaultPath: null,
        isVaultUnlocked: false,
        isVaultEncrypted: false,
        isAiEnabled: false,
        aiBaseUrl: '',
        aiEndpointMode: AiEndpointMode.localhostOnly,
        aiRemoteEndpointConfirmed: false,
      );

      expect(snapshot.isSemverValid, isFalse);
      expect(snapshot.activeVaultId, '-');
      expect(snapshot.activeVaultPath, '-');
      expect(snapshot.isReadyForRelease, isFalse);
      expect(snapshot.toReportText(), contains('IA habilitada: no'));
    });

    test('beta channel is warning and not a blocker', () {
      final snapshot = evaluateReleaseReadiness(
        installedVersionLabel: '1.0.0+7',
        updateReleaseChannel: UpdateReleaseChannel.beta,
        activeVaultId: 'vault-3',
        activeVaultPath: '/vaults/vault-3',
        isVaultUnlocked: true,
        isVaultEncrypted: true,
        isAiEnabled: false,
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
