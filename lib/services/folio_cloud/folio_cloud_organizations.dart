import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'folio_cloud_http_client.dart';
import 'folio_cloud_identity.dart';

/// Fase 12 del roadmap de Organizations — módulo de API cliente, espejo de
/// `folio_cloud_vault_share.dart`. Sin UI todavía: la usan las fases 13-14.
const Duration _kOrganizationsTimeout = Duration(seconds: 30);

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.plan,
  });

  final String id;
  final String name;
  final String type;
  final String plan;

  factory Organization.fromJson(Map<String, dynamic> m) {
    return Organization(
      id: '${m['id'] ?? ''}',
      name: '${m['name'] ?? ''}',
      type: '${m['type'] ?? ''}',
      plan: '${m['plan'] ?? ''}',
    );
  }

  bool get isPersonal => type == 'PERSONAL';
}

class OrganizationSummary extends Organization {
  const OrganizationSummary({
    required super.id,
    required super.name,
    required super.type,
    required super.plan,
    required this.role,
  });

  final String role;

  factory OrganizationSummary.fromJson(Map<String, dynamic> m) {
    return OrganizationSummary(
      id: '${m['id'] ?? ''}',
      name: '${m['name'] ?? ''}',
      type: '${m['type'] ?? ''}',
      plan: '${m['plan'] ?? ''}',
      role: '${m['role'] ?? 'MEMBER'}',
    );
  }
}

class OrganizationMember {
  const OrganizationMember({
    required this.id,
    required this.userId,
    required this.role,
    required this.status,
    this.email,
    this.displayName,
    this.joinedAt,
  });

  final String id;
  final String userId;
  final String? email;
  final String? displayName;
  final String role;
  final String status;
  final DateTime? joinedAt;

  factory OrganizationMember.fromJson(Map<String, dynamic> m) {
    return OrganizationMember(
      id: '${m['id'] ?? ''}',
      userId: '${m['userId'] ?? ''}',
      email: m['email']?.toString(),
      displayName: m['displayName']?.toString(),
      role: '${m['role'] ?? 'MEMBER'}',
      status: '${m['status'] ?? 'ACTIVE'}',
      joinedAt: DateTime.tryParse('${m['joinedAt'] ?? ''}'),
    );
  }
}

class OrganizationInvitation {
  const OrganizationInvitation({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String email;
  final String role;
  final String status;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory OrganizationInvitation.fromJson(Map<String, dynamic> m) {
    return OrganizationInvitation(
      id: '${m['id'] ?? ''}',
      email: '${m['email'] ?? ''}',
      role: '${m['role'] ?? 'MEMBER'}',
      status: '${m['status'] ?? 'PENDING'}',
      expiresAt: DateTime.tryParse('${m['expiresAt'] ?? ''}'),
      createdAt: DateTime.tryParse('${m['createdAt'] ?? ''}'),
    );
  }
}

class OrganizationInvitationPreview {
  const OrganizationInvitationPreview({
    required this.organizationName,
    required this.role,
    required this.status,
    this.inviterDisplayName,
    this.expiresAt,
  });

  final String organizationName;
  final String? inviterDisplayName;
  final String role;
  final DateTime? expiresAt;
  final String status;

  factory OrganizationInvitationPreview.fromJson(Map<String, dynamic> m) {
    return OrganizationInvitationPreview(
      organizationName: '${m['organizationName'] ?? ''}',
      inviterDisplayName: m['inviterDisplayName']?.toString(),
      role: '${m['role'] ?? 'MEMBER'}',
      expiresAt: DateTime.tryParse('${m['expiresAt'] ?? ''}'),
      status: '${m['status'] ?? 'PENDING'}',
    );
  }
}

class OrganizationSettings {
  const OrganizationSettings({
    this.language,
    this.timezone,
    this.theme,
    this.logoUrl,
    this.brandColor,
  });

  final String? language;
  final String? timezone;
  final String? theme;
  final String? logoUrl;
  final String? brandColor;

  factory OrganizationSettings.fromJson(Map<String, dynamic> m) {
    return OrganizationSettings(
      language: m['language']?.toString(),
      timezone: m['timezone']?.toString(),
      theme: m['theme']?.toString(),
      logoUrl: m['logoUrl']?.toString(),
      brandColor: m['brandColor']?.toString(),
    );
  }
}

class OrganizationInkBalance {
  const OrganizationInkBalance({
    required this.monthlyBalance,
    required this.purchasedBalance,
  });

  final int monthlyBalance;
  final int purchasedBalance;
  int get total => monthlyBalance + purchasedBalance;

  factory OrganizationInkBalance.fromJson(Map<String, dynamic> m) {
    return OrganizationInkBalance(
      monthlyBalance: (m['monthlyBalance'] as num?)?.toInt() ?? 0,
      purchasedBalance: (m['purchasedBalance'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrganizationStorageStatus {
  const OrganizationStorageStatus({
    required this.backendType,
    required this.quotaBaseBytes,
    required this.purchasedBytes,
    required this.usedBytes,
    required this.effectiveQuotaBytes,
  });

  final String backendType;
  final int quotaBaseBytes;
  final int purchasedBytes;
  final int usedBytes;
  final int effectiveQuotaBytes;

  factory OrganizationStorageStatus.fromJson(Map<String, dynamic> m) {
    return OrganizationStorageStatus(
      backendType: '${m['backendType'] ?? 'MANAGED'}',
      quotaBaseBytes: (m['quotaBaseBytes'] as num?)?.toInt() ?? 0,
      purchasedBytes: (m['purchasedBytes'] as num?)?.toInt() ?? 0,
      usedBytes: (m['usedBytes'] as num?)?.toInt() ?? 0,
      effectiveQuotaBytes: (m['effectiveQuotaBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrganizationActivityLogEntry {
  const OrganizationActivityLogEntry({
    required this.id,
    required this.eventType,
    this.actorUserId,
    this.metadata,
    this.createdAt,
  });

  final String id;
  final String? actorUserId;
  final String eventType;
  final String? metadata;
  final DateTime? createdAt;

  factory OrganizationActivityLogEntry.fromJson(Map<String, dynamic> m) {
    return OrganizationActivityLogEntry(
      id: '${m['id'] ?? ''}',
      actorUserId: m['actorUserId']?.toString(),
      eventType: '${m['eventType'] ?? ''}',
      metadata: m['metadata']?.toString(),
      createdAt: DateTime.tryParse('${m['createdAt'] ?? ''}'),
    );
  }
}

class OrganizationWorkspace {
  const OrganizationWorkspace({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.visibility,
    this.createdByUserId,
    this.createdAt,
    this.archivedAt,
  });

  final String id;
  final String organizationId;
  final String name;
  final String visibility;
  final String? createdByUserId;
  final DateTime? createdAt;
  final DateTime? archivedAt;

  factory OrganizationWorkspace.fromJson(Map<String, dynamic> m) {
    return OrganizationWorkspace(
      id: '${m['id'] ?? ''}',
      organizationId: '${m['organizationId'] ?? ''}',
      name: '${m['name'] ?? ''}',
      visibility: '${m['visibility'] ?? 'ORG_WIDE'}',
      createdByUserId: m['createdByUserId']?.toString(),
      createdAt: DateTime.tryParse('${m['createdAt'] ?? ''}'),
      archivedAt: m['archivedAt'] == null
          ? null
          : DateTime.tryParse('${m['archivedAt']}'),
    );
  }
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
  var res = await send(headers).timeout(_kOrganizationsTimeout);
  if (res.statusCode == 401) {
    headers = await _authHeaders(forceRefresh: true);
    res = await send(headers).timeout(_kOrganizationsTimeout);
  }
  return res;
}

void _ensureOk(http.Response res) {
  if (res.statusCode >= 200 && res.statusCode < 300) return;
  throw StateError('organizations HTTP ${res.statusCode}: ${res.body}');
}

Map<String, dynamic> _decodeMap(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) throw StateError('organizations: expected JSON object');
  return decoded.map((k, v) => MapEntry('$k', v));
}

List<Map<String, dynamic>> _decodeList(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) throw StateError('organizations: expected JSON array');
  return decoded.whereType<Map>().map((e) => e.map((k, v) => MapEntry('$k', v))).toList();
}

Uri _uri(String path) => Uri.parse('${FolioBackendConfig.apiV1Prefix}/organizations$path');

Future<Organization> createOrganization({required String name}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(_uri(''), headers: h, body: jsonEncode({'name': name})),
  );
  _ensureOk(res);
  return Organization.fromJson(_decodeMap(res.body));
}

Future<List<OrganizationSummary>> fetchMyOrganizations() async {
  final res = await _authorized((h) => folioCloudHttpClient.get(_uri('/mine'), headers: h));
  _ensureOk(res);
  return _decodeList(res.body).map(OrganizationSummary.fromJson).toList();
}

Future<Organization> fetchOrganization(String orgId) async {
  final res = await _authorized((h) => folioCloudHttpClient.get(_uri('/$orgId'), headers: h));
  _ensureOk(res);
  return Organization.fromJson(_decodeMap(res.body));
}

Future<Organization> renameOrganization({required String orgId, required String name}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.patch(_uri('/$orgId'), headers: h, body: jsonEncode({'name': name})),
  );
  _ensureOk(res);
  return Organization.fromJson(_decodeMap(res.body));
}

Future<OrganizationSettings> fetchOrganizationSettings(String orgId) async {
  final res = await _authorized((h) => folioCloudHttpClient.get(_uri('/$orgId/settings'), headers: h));
  _ensureOk(res);
  return OrganizationSettings.fromJson(_decodeMap(res.body));
}

Future<OrganizationSettings> updateOrganizationSettings({
  required String orgId,
  String? language,
  String? timezone,
  String? theme,
  String? logoUrl,
  String? brandColor,
}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.patch(
      _uri('/$orgId/settings'),
      headers: h,
      body: jsonEncode({
        if (language != null) 'language': language,
        if (timezone != null) 'timezone': timezone,
        if (theme != null) 'theme': theme,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (brandColor != null) 'brandColor': brandColor,
      }),
    ),
  );
  _ensureOk(res);
  return OrganizationSettings.fromJson(_decodeMap(res.body));
}

Future<List<OrganizationMember>> fetchOrganizationMembers(String orgId) async {
  final res = await _authorized((h) => folioCloudHttpClient.get(_uri('/$orgId/members'), headers: h));
  _ensureOk(res);
  return _decodeList(res.body).map(OrganizationMember.fromJson).toList();
}

Future<OrganizationMember> changeOrganizationMemberRole({
  required String orgId,
  required String memberId,
  required String role,
}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.patch(
      _uri('/$orgId/members/$memberId'),
      headers: h,
      body: jsonEncode({'role': role}),
    ),
  );
  _ensureOk(res);
  return OrganizationMember.fromJson(_decodeMap(res.body));
}

Future<void> removeOrganizationMember({required String orgId, required String memberId}) async {
  final res = await _authorized((h) => folioCloudHttpClient.delete(_uri('/$orgId/members/$memberId'), headers: h));
  _ensureOk(res);
}

Future<void> leaveOrganization(String orgId) async {
  final res = await _authorized((h) => folioCloudHttpClient.post(_uri('/$orgId/members/leave'), headers: h));
  _ensureOk(res);
}

Future<List<OrganizationActivityLogEntry>> fetchOrganizationActivity(String orgId, {int limit = 50}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.get(_uri('/$orgId/activity?limit=$limit'), headers: h),
  );
  _ensureOk(res);
  return _decodeList(res.body).map(OrganizationActivityLogEntry.fromJson).toList();
}

Future<OrganizationInvitation> inviteOrganizationMember({
  required String orgId,
  required String email,
  required String role,
}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      _uri('/$orgId/invitations'),
      headers: h,
      body: jsonEncode({'email': email.trim(), 'role': role}),
    ),
  );
  _ensureOk(res);
  return OrganizationInvitation.fromJson(_decodeMap(res.body));
}

Future<List<OrganizationInvitation>> fetchOrganizationInvitations(String orgId) async {
  final res = await _authorized((h) => folioCloudHttpClient.get(_uri('/$orgId/invitations'), headers: h));
  _ensureOk(res);
  return _decodeList(res.body).map(OrganizationInvitation.fromJson).toList();
}

Future<void> revokeOrganizationInvitation({required String orgId, required String invitationId}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.delete(_uri('/$orgId/invitations/$invitationId'), headers: h),
  );
  _ensureOk(res);
}

/// Pública — sin auth (preview para la página de aceptación).
Future<OrganizationInvitationPreview> previewOrganizationInvitation(String token) async {
  final res = await folioCloudHttpClient
      .get(
        _uri('/invitations/${Uri.encodeComponent(token)}'),
        headers: const {'Accept': 'application/json'},
      )
      .timeout(_kOrganizationsTimeout);
  _ensureOk(res);
  return OrganizationInvitationPreview.fromJson(_decodeMap(res.body));
}

Future<void> acceptOrganizationInvitation(String token) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      _uri('/invitations/accept'),
      headers: h,
      body: jsonEncode({'token': token}),
    ),
  );
  _ensureOk(res);
}

Future<OrganizationInkBalance> fetchOrganizationInk(String orgId) async {
  final res = await _authorized((h) => folioCloudHttpClient.get(_uri('/$orgId/ink'), headers: h));
  _ensureOk(res);
  return OrganizationInkBalance.fromJson(_decodeMap(res.body));
}

Future<OrganizationStorageStatus> fetchOrganizationStorage(String orgId) async {
  final res = await _authorized((h) => folioCloudHttpClient.get(_uri('/$orgId/storage'), headers: h));
  _ensureOk(res);
  return OrganizationStorageStatus.fromJson(_decodeMap(res.body));
}

Future<OrganizationWorkspace> createOrganizationWorkspace({required String orgId, required String name}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      _uri('/$orgId/workspaces'),
      headers: h,
      body: jsonEncode({'name': name}),
    ),
  );
  _ensureOk(res);
  return OrganizationWorkspace.fromJson(_decodeMap(res.body));
}

Future<List<OrganizationWorkspace>> fetchOrganizationWorkspaces(String orgId) async {
  final res = await _authorized((h) => folioCloudHttpClient.get(_uri('/$orgId/workspaces'), headers: h));
  _ensureOk(res);
  return _decodeList(res.body).map(OrganizationWorkspace.fromJson).toList();
}

Future<OrganizationWorkspace> renameOrganizationWorkspace({
  required String orgId,
  required String workspaceId,
  required String name,
}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.patch(
      _uri('/$orgId/workspaces/$workspaceId'),
      headers: h,
      body: jsonEncode({'name': name}),
    ),
  );
  _ensureOk(res);
  return OrganizationWorkspace.fromJson(_decodeMap(res.body));
}

Future<void> archiveOrganizationWorkspace({required String orgId, required String workspaceId}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.delete(_uri('/$orgId/workspaces/$workspaceId'), headers: h),
  );
  _ensureOk(res);
}

/// Solo OWNER/ADMIN (BILLING_MANAGE). Devuelve `{url: "https://checkout.stripe.com/..."}`.
Future<Map<String, String>> createOrganizationCheckoutSession(String orgId, {bool debug = false}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      _uri('/$orgId/billing/checkout-session'),
      headers: h,
      body: jsonEncode({'debug': debug}),
    ),
  );
  _ensureOk(res);
  return _decodeMap(res.body).map((k, v) => MapEntry(k, '$v'));
}

Future<Map<String, String>> createOrganizationPortalSession(String orgId, {bool debug = false}) async {
  final res = await _authorized(
    (h) => folioCloudHttpClient.post(
      _uri('/$orgId/billing/portal-session'),
      headers: h,
      body: jsonEncode({'debug': debug}),
    ),
  );
  _ensureOk(res);
  return _decodeMap(res.body).map((k, v) => MapEntry(k, '$v'));
}

Future<Map<String, dynamic>> fetchOrganizationBillingStatus(String orgId) async {
  final res = await _authorized((h) => folioCloudHttpClient.get(_uri('/$orgId/billing'), headers: h));
  _ensureOk(res);
  return _decodeMap(res.body);
}
