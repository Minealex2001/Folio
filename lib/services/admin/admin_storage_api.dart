import 'package:http/http.dart' as http;

import '../../config/folio_backend_config.dart';
import 'admin_api_base.dart';

/// Admin console: `/api/v1/admin/storage/**` — cloud-sync ("libretas") and backup cleanup per
/// user, plus a bucket-wide object explorer. See `AdminStorageService` (backend) for why
/// device-sync vaults and backup vaults are two separate, independently-deletable things.
class AdminStorageApi extends AdminApiBase {
  const AdminStorageApi();

  String _base(String uid) =>
      '${FolioBackendConfig.apiV1Prefix}/admin/storage/users/$uid';

  Future<Map<String, dynamic>> summary(String uid) async {
    final res = await authorized(
      (h) => http.get(Uri.parse('${_base(uid)}/summary'), headers: h),
    );
    ensureOk(res);
    return jsonMap(res);
  }

  Future<List<Map<String, dynamic>>> listDeviceSyncVaults(String uid) async {
    final res = await authorized(
      (h) => http.get(Uri.parse('${_base(uid)}/device-sync-vaults'), headers: h),
    );
    ensureOk(res);
    return jsonList(jsonMap(res)['vaults']);
  }

  Future<void> trashDeviceSyncVault(String uid, String vaultId) async {
    final res = await authorized(
      (h) => http.post(
        Uri.parse('${_base(uid)}/device-sync-vaults/$vaultId/trash'),
        headers: h,
      ),
    );
    ensureOk(res);
  }

  Future<void> restoreDeviceSyncVault(String uid, String vaultId) async {
    final res = await authorized(
      (h) => http.post(
        Uri.parse('${_base(uid)}/device-sync-vaults/$vaultId/restore'),
        headers: h,
      ),
    );
    ensureOk(res);
  }

  Future<Map<String, dynamic>> purgeDeviceSyncVault(String uid, String vaultId) async {
    final res = await authorized(
      (h) => http.post(
        Uri.parse('${_base(uid)}/device-sync-vaults/$vaultId/purge'),
        headers: h,
      ),
    );
    ensureOk(res);
    return jsonMap(res);
  }

  Future<List<Map<String, dynamic>>> listBackupVaults(String uid) async {
    final res = await authorized(
      (h) => http.get(Uri.parse('${_base(uid)}/backup-vaults'), headers: h),
    );
    ensureOk(res);
    return jsonList(jsonMap(res)['vaults']);
  }

  Future<Map<String, dynamic>> deleteBackupVault(String uid, String vaultId) async {
    final res = await authorized(
      (h) => http.post(
        Uri.parse('${_base(uid)}/backup-vaults/$vaultId/delete'),
        headers: h,
      ),
    );
    ensureOk(res);
    return jsonMap(res);
  }

  Future<Map<String, dynamic>> resetCloudSync(String uid) async {
    final res = await authorized(
      (h) => http.post(Uri.parse('${_base(uid)}/reset'), headers: h),
    );
    ensureOk(res);
    return jsonMap(res);
  }

  Future<
      ({
        List<String> commonPrefixes,
        List<Map<String, dynamic>> objects,
        String? nextContinuationToken,
      })> listObjects({
    String prefix = '',
    String delimiter = '/',
    String? continuationToken,
    int maxKeys = 200,
  }) async {
    final uri =
        Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/storage/objects').replace(
      queryParameters: {
        'prefix': prefix,
        'delimiter': delimiter,
        if (continuationToken != null && continuationToken.isNotEmpty)
          'continuationToken': continuationToken,
        'maxKeys': '$maxKeys',
      },
    );
    final res = await authorized((h) => http.get(uri, headers: h));
    ensureOk(res);
    final map = jsonMap(res);
    final prefixes = (map['commonPrefixes'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    return (
      commonPrefixes: prefixes,
      objects: jsonList(map['objects']),
      nextContinuationToken: map['nextContinuationToken'] as String?,
    );
  }

  Future<void> deleteObject(String path) async {
    final uri = Uri.parse('${FolioBackendConfig.apiV1Prefix}/admin/storage/objects')
        .replace(queryParameters: {'path': path});
    final res = await authorized((h) => http.delete(uri, headers: h));
    ensureOk(res, allowNoContent: true);
  }
}
