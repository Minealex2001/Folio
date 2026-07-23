/// Verificación de extremo a extremo del pipeline de device-sync (v2:
/// blobs content-addressed + manifiesto cifrado + Cloud Function
/// `folioFinalizeDeviceSync`) contra el **emulador local** de Firebase
/// (Auth + Firestore + Storage + Functions), no contra mocks.
///
/// A diferencia de `flutter test`, este es un script Dart plano (sin
/// bindings de Flutter) porque `Firebase.initializeApp()` de los plugins
/// Flutter no funciona bajo `flutter test` (falta el canal de plataforma).
/// En su lugar habla directamente por REST/HTTP con los emuladores, usando
/// el mismo formato de cifrado y las mismas rutas Storage/Firestore que usa
/// la app real (`cloudPackEncryptPlainBlob`, `folio_cloud_pack_crypto.dart`),
/// y el mismo protocolo HTTP callable que usa `_callFolioHttpsViaHttp` en
/// Windows/Linux.
///
/// Requiere los emuladores corriendo:
/// ```powershell
/// firebase emulators:start --only auth,firestore,storage,functions --project demo-folio-emulator-test
/// ```
///
/// Uso:
/// ```powershell
/// dart run tool/verify_device_sync_against_emulator.dart
/// ```
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../lib/crypto/vault_crypto.dart';
import '../lib/services/folio_cloud/folio_cloud_pack_crypto.dart';

const _projectId = 'demo-folio-emulator-test';
const _region = 'us-central1';
const _authBase = 'http://127.0.0.1:9099';
const _firestoreBase = 'http://127.0.0.1:8180';
const _storageBase = 'http://127.0.0.1:9199';
const _functionsBase = 'http://127.0.0.1:5001';
const _bucket = 'demo-folio-emulator-test.appspot.com';

int _checks = 0;

void _check(bool condition, String description) {
  _checks++;
  if (!condition) {
    stderr.writeln('FALLÓ: $description');
    exit(1);
  }
  print('  ok: $description');
}

Future<void> main() async {
  final vaultId = 'emu-test-vault-${DateTime.now().millisecondsSinceEpoch}';
  print('== Verificación device-sync vs emulador ($vaultId) ==\n');

  print('1) Alta de usuario de prueba en Auth emulator...');
  final email = 'device-sync-test-${DateTime.now().millisecondsSinceEpoch}@example.com';
  final signUp = await _authSignUp(email: email, password: 'Test1234!');
  final uid = signUp['localId'] as String;
  final idToken = signUp['idToken'] as String;
  print('   uid=$uid\n');

  print('2) Sembrando entitlement Folio Cloud backup en Firestore...');
  await _seedBackupEntitlement(uid);
  print('   listo\n');

  print('3) Dispositivo A: construye + cifra + sube payload inicial...');
  final packKey = SecretKey(List<int>.generate(32, (i) => (i * 7 + 3) % 256));
  final deviceAPayload = jsonEncode({
    'pages': [
      {
        'id': 'page-a1',
        'title': 'Nota del dispositivo A',
        'blocks': [
          {'id': 'b1', 'type': 'paragraph', 'text': 'contenido real vía emulador'},
        ],
      },
    ],
  });
  final pushA = await _pushDeviceSync(
    uid: uid,
    vaultId: vaultId,
    idToken: idToken,
    packKey: packKey,
    payloadJson: deviceAPayload,
    deviceId: 'device-a',
    deviceName: 'Dispositivo A',
    previousBlobIds: const {},
    oldManifestPath: '',
  );
  print('   manifest=${pushA.manifestPath} rev=${pushA.rev}\n');

  print('4) Dispositivo B: descubre el manifiesto vía folioGetDeviceSyncMeta...');
  final metaForB = await _getDeviceSyncMeta(
    idToken: idToken,
    vaultId: vaultId,
  );
  _check(
    metaForB['manifestStoragePath'] == pushA.manifestPath,
    'folioGetDeviceSyncMeta devuelve el manifiesto que subió A',
  );

  print('5) Dispositivo B: descarga + descifra el manifiesto y el payload...');
  final pulledA = await _pullDeviceSync(
    manifestStoragePath: metaForB['manifestStoragePath'] as String,
    idToken: idToken,
    packKey: packKey,
  );
  _check(
    pulledA == deviceAPayload,
    'el payload descifrado por B coincide byte a byte con lo que subió A',
  );

  print('\n6) Dispositivo B: edita y sube una nueva versión...');
  final deviceBPayload = jsonEncode({
    'pages': [
      {
        'id': 'page-a1',
        'title': 'Nota del dispositivo A',
        'blocks': [
          {'id': 'b1', 'type': 'paragraph', 'text': 'editado por B'},
        ],
      },
      {
        'id': 'page-b1',
        'title': 'Página nueva de B',
        'blocks': [
          {'id': 'b2', 'type': 'paragraph', 'text': 'añadida por B'},
        ],
      },
    ],
  });
  final pushB = await _pushDeviceSync(
    uid: uid,
    vaultId: vaultId,
    idToken: idToken,
    packKey: packKey,
    payloadJson: deviceBPayload,
    deviceId: 'device-b',
    deviceName: 'Dispositivo B',
    previousBlobIds: pushA.blobIds,
    oldManifestPath: pushA.manifestPath,
  );
  print('   manifest=${pushB.manifestPath} rev=${pushB.rev}\n');
  _check(pushB.rev > pushA.rev, 'el rev de Firestore avanza en el segundo push');

  print('7) Dispositivo A: vuelve a preguntar y ve la versión de B...');
  final metaForA = await _getDeviceSyncMeta(idToken: idToken, vaultId: vaultId);
  _check(
    metaForA['manifestStoragePath'] == pushB.manifestPath,
    'A ve el manifiesto más reciente (el de B), no el suyo propio',
  );
  final pulledB = await _pullDeviceSync(
    manifestStoragePath: metaForA['manifestStoragePath'] as String,
    idToken: idToken,
    packKey: packKey,
  );
  _check(
    pulledB == deviceBPayload,
    'A descifra correctamente el contenido editado por B (2 páginas)',
  );

  print('\nTodo OK — $_checks comprobaciones pasaron contra Auth+Firestore+Storage+Functions reales (emulados).');
}

Future<Map<String, dynamic>> _authSignUp({
  required String email,
  required String password,
}) async {
  final resp = await http.post(
    Uri.parse('$_authBase/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );
  if (resp.statusCode != 200) {
    throw StateError('Auth signUp failed: ${resp.statusCode} ${resp.body}');
  }
  return jsonDecode(resp.body) as Map<String, dynamic>;
}

Future<void> _seedBackupEntitlement(String uid) async {
  final uri = Uri.parse(
    '$_firestoreBase/v1/projects/$_projectId/databases/(default)/documents/users/$uid'
    '?updateMask.fieldPaths=folioCloud',
  );
  final resp = await http.patch(
    uri,
    headers: {
      'Authorization': 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'fields': {
        'folioCloud': {
          'mapValue': {
            'fields': {
              'active': {'booleanValue': true},
              'features': {
                'mapValue': {
                  'fields': {
                    'backup': {'booleanValue': true},
                  },
                },
              },
            },
          },
        },
      },
    }),
  );
  if (resp.statusCode != 200) {
    throw StateError('Firestore seed failed: ${resp.statusCode} ${resp.body}');
  }
}

class _PushResult {
  _PushResult({required this.manifestPath, required this.blobIds, required this.rev});
  final String manifestPath;
  final Set<String> blobIds;
  final int rev;
}

Future<_PushResult> _pushDeviceSync({
  required String uid,
  required String vaultId,
  required String idToken,
  required SecretKey packKey,
  required String payloadJson,
  required String deviceId,
  required String deviceName,
  required Set<String> previousBlobIds,
  required String oldManifestPath,
}) async {
  final payloadBytes = Uint8List.fromList(utf8.encode(payloadJson));
  final payloadCipher = await cloudPackEncryptPlainBlob(
    plain: payloadBytes,
    packKey: packKey,
    role: 'device-sync-payload',
  );
  final payloadBlobId = await cloudPackBlobIdFromCipherBytes(payloadCipher);

  final newBlobIds = <String>{payloadBlobId}.difference(previousBlobIds);
  for (final blobId in newBlobIds) {
    await _storageUpload(
      path: 'users/$uid/vaults/$vaultId/device-sync/blobs/$blobId',
      bytes: payloadCipher,
      idToken: idToken,
    );
  }

  final fingerprint = _hexSha256(payloadBytes);
  final manifestClear = jsonEncode({
    'format': 'folio.device.sync.manifest.v2',
    'formatVersion': 2,
    'contentFingerprint': fingerprint,
    'payloadBlobId': payloadBlobId,
    'attachments': <Object?>[],
  });
  final manifestCipher = await cloudPackEncryptBytes(
    plain: utf8.encode(manifestClear),
    packKey: packKey,
  );
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final manifestPath =
      'users/$uid/vaults/$vaultId/device-sync/manifests/manifest-$stamp.bin';
  await _storageUpload(path: manifestPath, bytes: manifestCipher, idToken: idToken);

  final result = await _callCallable(
    name: 'folioFinalizeDeviceSync',
    idToken: idToken,
    data: {
      'vaultId': vaultId,
      'syncFormatVersion': 2,
      'manifestStoragePath': manifestPath,
      'manifestSizeBytes': manifestCipher.length,
      'contentFingerprint': fingerprint,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'newBlobs': [
        for (final id in newBlobIds) {'blobId': id, 'sizeBytes': payloadCipher.length},
      ],
      if (oldManifestPath.isNotEmpty) 'oldManifestStoragePath': oldManifestPath,
    },
  );
  final rev = (result['rev'] as num?)?.toInt() ?? 0;
  return _PushResult(
    manifestPath: manifestPath,
    blobIds: {payloadBlobId},
    rev: rev,
  );
}

Future<String> _pullDeviceSync({
  required String manifestStoragePath,
  required String idToken,
  required SecretKey packKey,
}) async {
  final manifestCipher = await _storageDownload(
    path: manifestStoragePath,
    idToken: idToken,
  );
  final manifestPlain = await cloudPackDecryptBytes(
    blob: manifestCipher,
    packKey: packKey,
  );
  final manifest = jsonDecode(utf8.decode(manifestPlain)) as Map<String, dynamic>;
  final payloadBlobId = manifest['payloadBlobId'] as String;

  final pathParts = manifestStoragePath.split('/');
  final uid = pathParts[1];
  final vaultId = pathParts[3];
  final payloadCipher = await _storageDownload(
    path: 'users/$uid/vaults/$vaultId/device-sync/blobs/$payloadBlobId',
    idToken: idToken,
  );
  final payloadPlain = await cloudPackDecryptBytes(
    blob: payloadCipher,
    packKey: packKey,
  );
  return utf8.decode(payloadPlain);
}

Future<Map<String, dynamic>> _getDeviceSyncMeta({
  required String idToken,
  required String vaultId,
}) => _callCallable(
  name: 'folioGetDeviceSyncMeta',
  idToken: idToken,
  data: {'vaultId': vaultId},
);

Future<Map<String, dynamic>> _callCallable({
  required String name,
  required String idToken,
  required Map<String, dynamic> data,
}) async {
  final uri = Uri.parse('$_functionsBase/$_projectId/$_region/$name');
  final resp = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'data': data}),
  );
  final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
  if (decoded.containsKey('error')) {
    throw StateError('Callable $name failed: ${decoded['error']}');
  }
  return Map<String, dynamic>.from(decoded['result'] as Map);
}

Future<void> _storageUpload({
  required String path,
  required List<int> bytes,
  required String idToken,
}) async {
  final uri = Uri.parse(
    '$_storageBase/v0/b/$_bucket/o?uploadType=media&name=${Uri.encodeComponent(path)}',
  );
  final resp = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/octet-stream',
    },
    body: bytes,
  );
  if (resp.statusCode != 200) {
    throw StateError('Storage upload failed ($path): ${resp.statusCode} ${resp.body}');
  }
}

Future<Uint8List> _storageDownload({
  required String path,
  required String idToken,
}) async {
  final uri = Uri.parse(
    '$_storageBase/v0/b/$_bucket/o/${Uri.encodeComponent(path)}?alt=media',
  );
  final resp = await http.get(uri, headers: {'Authorization': 'Bearer $idToken'});
  if (resp.statusCode != 200) {
    throw StateError('Storage download failed ($path): ${resp.statusCode} ${resp.body}');
  }
  return resp.bodyBytes;
}

String _hexSha256(List<int> bytes) {
  var hash = 0x811c9dc5;
  // Fingerprint simple (no necesita ser SHA-256 real para este script: solo
  // debe cumplir el regex hex que valida la Cloud Function). Usamos un hash
  // legible determinista para depuración.
  final sb = StringBuffer();
  for (final b in bytes) {
    hash = ((hash ^ b) * 0x01000193) & 0xffffffff;
    sb.write(hash.toRadixString(16).padLeft(8, '0'));
  }
  final full = sb.toString();
  return full.length > 64 ? full.substring(0, 64) : full.padRight(64, '0');
}
