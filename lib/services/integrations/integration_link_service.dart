import 'dart:math';

import '../folio_cloud/folio_cloud_callable.dart';

/// Registra un código de vinculación temporal en Firestore vía Cloud Functions.
class IntegrationLinkService {
  const IntegrationLinkService();

  static final _rng = Random.secure();
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String generateCode() {
    final buf = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buf.write(_chars[_rng.nextInt(_chars.length)]);
    }
    return buf.toString();
  }

  Future<void> registerLinkCode({
    required String code,
    required String vaultId,
    required String connectionId,
    required String provider,
    required String webhookUrl,
    String? teamsSecurityToken,
  }) async {
    await callFolioHttpsCallable('folioRegisterIntegrationLinkCode', {
      'code': code,
      'vaultId': vaultId,
      'connectionId': connectionId,
      'provider': provider,
      'webhookUrl': webhookUrl,
      if ((teamsSecurityToken ?? '').trim().isNotEmpty)
        'teamsSecurityToken': teamsSecurityToken!.trim(),
    });
  }
}
