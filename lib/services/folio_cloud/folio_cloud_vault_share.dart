import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import '../../crypto/vault_share_crypto.dart';
import '../../models/folio_page.dart';
import 'folio_cloud_entitlements.dart';
import 'folio_cloud_http_client.dart';
import 'folio_cloud_identity.dart';
import 'folio_spring_storage.dart';

const Duration _kVaultShareTimeout = Duration(seconds: 30);

class VaultPublicShareState {
  const VaultPublicShareState({
    required this.enabled,
    this.token,
    this.publicUrl,
    this.contentUrl,
    this.displayName,
    this.rev = 0,
    this.fingerprint = '',
  });

  final bool enabled;
  final String? token;
  final String? publicUrl;
  final String? contentUrl;
  final String? displayName;
  final int rev;
  final String fingerprint;

  factory VaultPublicShareState.fromJson(Map<String, dynamic> m) {
    return VaultPublicShareState(
      enabled: m['enabled'] == true,
      token: m['token']?.toString(),
      publicUrl: m['publicUrl']?.toString(),
      contentUrl: m['contentUrl']?.toString(),
      displayName: m['displayName']?.toString(),
      rev: (m['rev'] as num?)?.toInt() ?? 0,
      fingerprint: '${m['fingerprint'] ?? ''}',
    );
  }
}

class VaultSharedWithMeEntry {
  const VaultSharedWithMeEntry({
    required this.ownerUid,
    required this.vaultId,
    required this.displayName,
    required this.role,
    this.ownerDisplayName,
    this.ownerEmail,
    this.dekWrapB64,
    this.membershipId,
    this.rev = 0,
    this.contentFingerprint = '',
  });

  final String ownerUid;
  final String vaultId;
  final String displayName;
  final String role;
  final String? ownerDisplayName;
  final String? ownerEmail;
  final String? dekWrapB64;
  final String? membershipId;
  final int rev;
  final String contentFingerprint;

  bool get canDelete => false;

  factory VaultSharedWithMeEntry.fromJson(Map<String, dynamic> m) {
    return VaultSharedWithMeEntry(
      ownerUid: '${m['ownerUid'] ?? ''}',
      vaultId: '${m['vaultId'] ?? ''}',
      displayName: '${m['displayName'] ?? 'Libreta compartida'}',
      role: '${m['role'] ?? 'editor'}',
      ownerDisplayName: m['ownerDisplayName']?.toString(),
      ownerEmail: m['ownerEmail']?.toString(),
      dekWrapB64: m['dekWrapB64']?.toString(),
      membershipId: m['membershipId']?.toString(),
      rev: (m['rev'] as num?)?.toInt() ?? 0,
      contentFingerprint: '${m['contentFingerprint'] ?? ''}',
    );
  }
}

class VaultMemberInviteResult {
  const VaultMemberInviteResult({
    required this.membershipId,
    required this.shareCode,
    required this.inviteEmail,
  });

  final String membershipId;
  final String shareCode;
  final String inviteEmail;
}

Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
  final token = await folioCloudBearerToken(forceRefresh: forceRefresh);
  if (token == null || token.isEmpty) {
    throw StateError('Not signed in');
  }
  return <String, String>{
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };
}

Future<http.Response> _authorized(
  Future<http.Response> Function(Map<String, String> headers) send,
) async {
  var headers = await _authHeaders();
  var res = await send(headers).timeout(_kVaultShareTimeout);
  if (res.statusCode == 401) {
    headers = await _authHeaders(forceRefresh: true);
    res = await send(headers).timeout(_kVaultShareTimeout);
  }
  return res;
}

void _ensureOk(http.Response res) {
  if (res.statusCode >= 200 && res.statusCode < 300) return;
  throw StateError('vault-shares HTTP ${res.statusCode}: ${res.body}');
}

Map<String, dynamic> _decodeMap(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) throw StateError('vault-shares: expected JSON object');
  return decoded.map((k, v) => MapEntry('$k', v));
}

/// Vista pública sanitizada de la libreta (sin secretos ni rutas locales).
Map<String, dynamic> buildVaultPublicViewPack({
  required String vaultId,
  required String displayName,
  required List<FolioPage> pages,
}) {
  final visible = pages.where((p) => !p.isTrashed).toList();
  return <String, dynamic>{
    'v': 1,
    'vaultId': vaultId,
    'displayName': displayName,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'pages': visible.map(_publicPageJson).toList(),
  };
}

Map<String, dynamic> _publicPageJson(FolioPage p) {
  final j = Map<String, dynamic>.from(p.toJson());
  j.remove('collabJoinCode');
  j.remove('collabRoomId');
  j.remove('lastImportInfo');
  final rawBlocks = j['blocks'];
  if (rawBlocks is List) {
    j['blocks'] = rawBlocks.map((raw) {
      if (raw is! Map) return raw;
      final b = Map<String, dynamic>.from(raw);
      final url = b['url']?.toString();
      if (url != null && !_isPublicHttpOrDataUrl(url)) {
        b.remove('url');
      }
      return b;
    }).toList();
  }
  return j;
}

bool _isPublicHttpOrDataUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('https://') ||
      u.startsWith('http://') ||
      u.startsWith('data:');
}

List<FolioPage> hydrateVaultPublicViewPages(Map<String, dynamic> content) {
  final raw = content['pages'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => FolioPage.fromJson(e.map((k, v) => MapEntry('$k', v))))
      .toList();
}

String fingerprintViewPack(Map<String, dynamic> pack) {
  final canonical = jsonEncode(pack);
  return sha256.convert(utf8.encode(canonical)).toString();
}

Future<VaultPublicShareState> enableVaultPublicShare({
  required String vaultId,
  required String displayName,
  FolioCloudSnapshot? entitlements,
}) async {
  if (entitlements != null && !entitlements.canPublishToWeb) {
    throw StateError(
      'Tu plan Folio Cloud no incluye publicación web o la suscripción no está activa.',
    );
  }
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      Uri.parse('${FolioBackendConfig.apiV1Prefix}/vault-shares/public/enable'),
      headers: h,
      body: jsonEncode({'vaultId': vaultId, 'displayName': displayName}),
    ),
  );
  _ensureOk(res);
  return VaultPublicShareState.fromJson(_decodeMap(res.body));
}

Future<VaultPublicShareState> fetchVaultPublicShareMine(String vaultId) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.get(
      Uri.parse(
        '${FolioBackendConfig.apiV1Prefix}/vault-shares/public/mine?vaultId=${Uri.encodeQueryComponent(vaultId)}',
      ),
      headers: h,
    ),
  );
  _ensureOk(res);
  return VaultPublicShareState.fromJson(_decodeMap(res.body));
}

/// Meta pública (sin auth) — viewer web `/s/{token}`.
Future<Map<String, dynamic>> fetchVaultPublicMetaUnauthed(String token) async {
  final res = await folioCloudHttpClient
      .get(
        Uri.parse(
          '${FolioBackendConfig.apiV1Prefix}/vault-shares/public/${Uri.encodeComponent(token)}',
        ),
        headers: const {'Accept': 'application/json'},
      )
      .timeout(_kVaultShareTimeout);
  _ensureOk(res);
  return _decodeMap(res.body);
}

/// Contenido del view-pack público (sin auth).
Future<Map<String, dynamic>> fetchVaultPublicContentUnauthed(String token) async {
  final res = await folioCloudHttpClient
      .get(
        Uri.parse(
          '${FolioBackendConfig.apiV1Prefix}/vault-shares/public/${Uri.encodeComponent(token)}/content',
        ),
        headers: const {'Accept': 'application/json'},
      )
      .timeout(_kVaultShareTimeout);
  _ensureOk(res);
  return _decodeMap(res.body);
}

Future<void> revokeVaultPublicShare(String vaultId) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      Uri.parse('${FolioBackendConfig.apiV1Prefix}/vault-shares/public/revoke'),
      headers: h,
      body: jsonEncode({'vaultId': vaultId}),
    ),
  );
  _ensureOk(res);
}

/// Sube view.json y actualiza meta (rev/fingerprint). Idempotente si fingerprint igual.
Future<VaultPublicShareState> publishVaultPublicViewContent({
  required String vaultId,
  required String ownerUid,
  required Map<String, dynamic> viewPack,
}) async {
  final fingerprint = fingerprintViewPack(viewPack);
  final prefix = 'shared-vaults/$ownerUid/$vaultId';
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(viewPack)));
  await folioSpringStoragePutData('$prefix/view.json', bytes);

  final res = await _authorized(
    (h) => folioCloudHttpClient.put(
      Uri.parse('${FolioBackendConfig.apiV1Prefix}/vault-shares/public/content'),
      headers: h,
      body: jsonEncode({
        'vaultId': vaultId,
        'contentFingerprint': fingerprint,
        'storagePrefix': prefix,
      }),
    ),
  );
  _ensureOk(res);
  return VaultPublicShareState.fromJson(_decodeMap(res.body));
}

/// Publica el view-pack si el enlace público está activo y el contenido cambió.
Future<VaultPublicShareState?> syncVaultPublicViewIfEnabled({
  required String vaultId,
  required String ownerUid,
  required String displayName,
  required List<FolioPage> pages,
  FolioCloudSnapshot? entitlements,
}) async {
  if (entitlements != null && !entitlements.canPublishToWeb) return null;
  final mine = await fetchVaultPublicShareMine(vaultId);
  if (!mine.enabled) return null;
  final pack = buildVaultPublicViewPack(
    vaultId: vaultId,
    displayName: displayName,
    pages: pages,
  );
  final fp = fingerprintViewPack(pack);
  if (fp == mine.fingerprint && mine.rev > 0) return mine;
  return publishVaultPublicViewContent(
    vaultId: vaultId,
    ownerUid: ownerUid,
    viewPack: pack,
  );
}

Future<VaultMemberInviteResult> inviteVaultMember({
  required String vaultId,
  required String email,
  required String displayName,
  required List<int> syncKeyBytes,
  required String ownerUid,
}) async {
  final shareCode = VaultShareCrypto.generateShareCode();
  final dekWrap = await VaultShareCrypto.wrapKeyB64(
    keyBytes: syncKeyBytes,
    shareCode: shareCode,
    ownerUid: ownerUid,
    vaultId: vaultId,
  );
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      Uri.parse('${FolioBackendConfig.apiV1Prefix}/vault-shares/members/invite'),
      headers: h,
      body: jsonEncode({
        'vaultId': vaultId,
        'email': email.trim(),
        'displayName': displayName,
        'dekWrapB64': dekWrap,
        'shareCode': shareCode,
      }),
    ),
  );
  _ensureOk(res);
  final m = _decodeMap(res.body);
  final serverCode = m['shareCode']?.toString() ?? shareCode;
  return VaultMemberInviteResult(
    membershipId: '${m['id'] ?? ''}',
    shareCode: serverCode,
    inviteEmail: '${m['inviteEmail'] ?? email}',
  );
}

Future<Map<String, dynamic>> acceptVaultShare({
  required String shareId,
  required String shareCode,
}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      Uri.parse('${FolioBackendConfig.apiV1Prefix}/vault-shares/members/accept'),
      headers: h,
      body: jsonEncode({'shareId': shareId, 'shareCode': shareCode}),
    ),
  );
  _ensureOk(res);
  return _decodeMap(res.body);
}

Future<void> leaveSharedVault({
  required String vaultId,
  required String ownerUid,
}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      Uri.parse('${FolioBackendConfig.apiV1Prefix}/vault-shares/members/leave'),
      headers: h,
      body: jsonEncode({'vaultId': vaultId, 'ownerUid': ownerUid}),
    ),
  );
  _ensureOk(res);
}

Future<void> removeVaultMember({
  required String vaultId,
  required String membershipId,
}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      Uri.parse('${FolioBackendConfig.apiV1Prefix}/vault-shares/members/remove'),
      headers: h,
      body: jsonEncode({'vaultId': vaultId, 'membershipId': membershipId}),
    ),
  );
  _ensureOk(res);
}

Future<List<Map<String, dynamic>>> listVaultMembers(String vaultId) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.get(
      Uri.parse(
        '${FolioBackendConfig.apiV1Prefix}/vault-shares/members?vaultId=${Uri.encodeQueryComponent(vaultId)}',
      ),
      headers: h,
    ),
  );
  _ensureOk(res);
  final m = _decodeMap(res.body);
  final list = m['members'];
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => e.map((k, v) => MapEntry('$k', v)))
      .toList();
}

Future<({List<VaultSharedWithMeEntry> vaults, List<Map<String, dynamic>> pending})>
    fetchSharedWithMe() async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.get(
      Uri.parse('${FolioBackendConfig.apiV1Prefix}/vault-shares/shared-with-me'),
      headers: h,
    ),
  );
  _ensureOk(res);
  final m = _decodeMap(res.body);
  final vaults = <VaultSharedWithMeEntry>[];
  final rawVaults = m['vaults'];
  if (rawVaults is List) {
    for (final e in rawVaults) {
      if (e is Map) {
        vaults.add(
          VaultSharedWithMeEntry.fromJson(e.map((k, v) => MapEntry('$k', v))),
        );
      }
    }
  }
  final pending = <Map<String, dynamic>>[];
  final rawPending = m['pending'];
  if (rawPending is List) {
    for (final e in rawPending) {
      if (e is Map) {
        pending.add(e.map((k, v) => MapEntry('$k', v)));
      }
    }
  }
  return (vaults: vaults, pending: pending);
}
