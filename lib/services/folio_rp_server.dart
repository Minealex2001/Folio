import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:flutter/foundation.dart';

import '../data/vault_paths.dart';
import '../data/storage/vault_storage.dart';
import 'platform/current_web_host.dart';
import 'webauthn/webauthn_verify.dart';

/// Relying party **local** para passkeys (mismo enfoque que el ejemplo oficial de `passkeys`).
/// Solo metadatos de credencial; no contiene el contenido de la libreta.
class FolioRpUser {
  FolioRpUser({
    required this.name,
    required this.id,
    this.credentialID,
    this.transports = const [],
    this.webAuthnPublicKey,
  });

  final String name;
  final String id;
  String? credentialID;
  List<String> transports;

  /// Clave pública COSE extraída en el registro (ver `webauthn_verify.dart`),
  /// usada para verificar criptográficamente la firma en cada login. Puede
  /// ser `null` para passkeys registradas antes de que esto existiera.
  Map<String, dynamic>? webAuthnPublicKey;

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'credentialID': credentialID,
    'transports': transports,
    if (webAuthnPublicKey != null) 'webAuthnPublicKey': webAuthnPublicKey,
  };

  factory FolioRpUser.fromJson(Map<String, dynamic> j) {
    return FolioRpUser(
      name: j['name'] as String,
      id: j['id'] as String,
      credentialID: j['credentialID'] as String?,
      transports:
          (j['transports'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      webAuthnPublicKey: (j['webAuthnPublicKey'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

/// ID de relying party. En web debe coincidir con el host real servido
/// (WebAuthn lo exige); en escritorio/móvil debe ser coherente con la plataforma.
String get folioRpId {
  if (kIsWeb) {
    return currentWebHost();
  }
  return 'folio.app';
}

class FolioRpServer {
  FolioRpServer();

  final Map<String, FolioRpUser> _users = HashMap();
  final Map<String, FolioRpUser> _inFlight = HashMap();
  final Random _random = Random.secure();

  static const String defaultUserName = 'folio';

  bool get hasPasskey =>
      _users[defaultUserName]?.credentialID != null &&
      _users[defaultUserName]!.credentialID!.isNotEmpty;

  Future<void> loadFromDisk() async {
    final raw = await VaultPaths.readRpState();
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final users = map['users'] as Map<String, dynamic>? ?? {};
      _users.clear();
      for (final e in users.entries) {
        _users[e.key] = FolioRpUser.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        );
      }
    } catch (_) {
      _users.clear();
    }
  }

  Future<void> saveToDisk() async {
    final users = <String, dynamic>{};
    for (final e in _users.entries) {
      users[e.key] = e.value.toJson();
    }
    await VaultPaths.writeRpState(jsonEncode({'users': users}));
  }

  String startPasskeyRegister() {
    final existing = _users[defaultUserName];
    if (existing?.credentialID != null && existing!.credentialID!.isNotEmpty) {
      throw StateError('Ya hay una passkey registrada. Revócala antes.');
    }
    final userID = existing?.id ?? 'user-${_random.nextInt(1 << 30)}';
    final newUser = FolioRpUser(
      id: userID,
      name: defaultUserName,
      transports: existing?.transports ?? [],
    );
    final challenge = generateChallenge();
    _inFlight[challenge] = newUser;

    final request = <String, dynamic>{
      'challenge': challenge,
      'rp': {'name': 'Folio', 'id': folioRpId},
      'user': {
        'id': base64Url.encode(userID.codeUnits),
        'name': defaultUserName,
        'displayName': 'Folio',
      },
      'pubKeyCredParams': [
        {'type': 'public-key', 'alg': -7},
        {'type': 'public-key', 'alg': -257},
      ],
      'authenticatorSelection': {
        'requireResidentKey': false,
        'residentKey': 'required',
        'userVerification': 'preferred',
      },
      'timeout': 60000,
    };
    return jsonEncode(request);
  }

  Uint8List _decodeBase64ToBytes(String value) {
    return Uint8List.fromList(base64.decode(addBase64Padding(value)));
  }

  Map<String, dynamic> _decodeClientDataJson(String clientDataJSON) {
    return jsonDecode(String.fromCharCodes(_decodeBase64ToBytes(clientDataJSON)))
        as Map<String, dynamic>;
  }

  void _assertPasskeyClientData({
    required Map<String, dynamic> clientData,
    required String expectedChallenge,
    required String expectedType,
  }) {
    final type = clientData['type'] as String?;
    if (type != expectedType) {
      throw StateError('Tipo WebAuthn inválido');
    }
    final challenge = clientData['challenge'] as String?;
    if (challenge == null || challenge != expectedChallenge) {
      throw StateError('Challenge passkey inválido');
    }
    final origin = clientData['origin'] as String?;
    if (origin != null &&
        origin.isNotEmpty &&
        !origin.contains(folioRpId) &&
        folioRpId != 'localhost') {
      throw StateError('Origen passkey no confiable');
    }
  }

  Future<void> finishPasskeyRegister({required String response}) async {
    final responseMap = jsonDecode(response) as Map<String, dynamic>;
    final responseData = responseMap['response'] as Map<String, dynamic>;
    final clientDataJSON = responseData['clientDataJSON'] as String;
    final id = responseMap['id'] as String;
    final transports = responseData['transports'] as List<dynamic>?;
    final attestationObjectB64 = responseData['attestationObject'] as String?;

    if (id.isEmpty) {
      throw StateError('Credential ID vacío');
    }
    if (attestationObjectB64 == null || attestationObjectB64.isEmpty) {
      throw StateError('Respuesta de registro sin attestationObject');
    }

    final clientData = _decodeClientDataJson(clientDataJSON);
    final challenge = clientData['challenge'] as String;
    final user = _inFlight[challenge];
    if (user == null) {
      throw StateError('Estado passkey inválido');
    }
    _assertPasskeyClientData(
      clientData: clientData,
      expectedChallenge: challenge,
      expectedType: 'webauthn.create',
    );

    // Extrae y guarda la clave pública COSE del autenticador — sin esto no
    // hay forma de verificar criptográficamente la firma en logins futuros.
    final publicKey = parsePublicKeyFromAttestationObject(
      _decodeBase64ToBytes(attestationObjectB64),
    );

    user
      ..credentialID = id
      ..transports = (transports?.isEmpty ?? true)
          ? ['internal', 'hybrid']
          : transports!.map((e) => e as String).toList()
      ..webAuthnPublicKey = publicKey.toJson();
    _users[user.name] = user;
    _inFlight.remove(challenge);
    await saveToDisk();
  }

  String startPasskeyLogin() {
    final u = _users[defaultUserName];
    if (u == null || u.credentialID == null) {
      throw StateError('No hay passkey registrada');
    }
    final challenge = generateChallenge();
    _inFlight[challenge] = u;

    final request = <String, dynamic>{
      'challenge': challenge,
      'rpId': folioRpId,
      'userVerification': 'preferred',
      'timeout': 60000,
      'allowCredentials': [
        {
          'type': 'public-key',
          'id': u.credentialID!,
          'transports': u.transports,
        },
      ],
    };
    return jsonEncode(request);
  }

  Future<void> finishPasskeyLogin({required String response}) async {
    final responseMap = jsonDecode(response) as Map<String, dynamic>;
    final responseData = responseMap['response'] as Map<String, dynamic>;
    final clientDataJSON = responseData['clientDataJSON'] as String;
    final credentialId = responseMap['id'] as String?;

    final clientData = _decodeClientDataJson(clientDataJSON);
    final challenge = clientData['challenge'] as String;
    final user = _inFlight[challenge];
    if (user == null) {
      throw StateError('Estado passkey inválido');
    }
    _assertPasskeyClientData(
      clientData: clientData,
      expectedChallenge: challenge,
      expectedType: 'webauthn.get',
    );
    final expectedId = user.credentialID;
    if (expectedId == null ||
        expectedId.isEmpty ||
        credentialId == null ||
        credentialId.isEmpty ||
        credentialId != expectedId) {
      throw StateError('Credential ID no coincide');
    }

    // Verificación criptográfica de la firma del autenticador. Passkeys
    // registradas antes de que esto existiera no tienen `webAuthnPublicKey`
    // guardada — para esas, solo queda el chequeo de campos JSON de arriba
    // (comportamiento previo), hasta que el usuario vuelva a registrar la
    // passkey.
    final storedPublicKey = WebAuthnPublicKey.tryParse(user.webAuthnPublicKey);
    if (storedPublicKey != null) {
      final authenticatorDataB64 = responseData['authenticatorData'] as String?;
      final signatureB64 = responseData['signature'] as String?;
      if (authenticatorDataB64 == null ||
          authenticatorDataB64.isEmpty ||
          signatureB64 == null ||
          signatureB64.isEmpty) {
        throw StateError('Respuesta passkey incompleta (falta firma)');
      }
      final authenticatorData = _decodeBase64ToBytes(authenticatorDataB64);
      final signature = _decodeBase64ToBytes(signatureB64);
      final clientDataHash = await Sha256().hash(_decodeBase64ToBytes(clientDataJSON));
      final signedData = Uint8List.fromList([
        ...authenticatorData,
        ...clientDataHash.bytes,
      ]);
      final verified = verifyWebAuthnSignature(
        publicKey: storedPublicKey,
        signedData: signedData,
        derSignature: signature,
      );
      if (!verified) {
        throw StateError('Firma passkey inválida');
      }
    }

    _inFlight.remove(challenge);
  }

  Future<void> clearPasskey() async {
    _users.remove(defaultUserName);
    _inFlight.clear();
    final id = VaultPaths.activeVaultId;
    if (id != null) {
      await VaultStorage.instance.deleteVaultFile(id, VaultPaths.rpStateFile);
    }
  }

  String generateChallenge() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    var rawChallenge = '';
    for (var i = 0; i < 32; i++) {
      rawChallenge += chars[_random.nextInt(chars.length)];
    }
    final a = base64Url.encode(rawChallenge.codeUnits);
    return a.substring(0, a.length - 1);
  }

  String addBase64Padding(String base64String) {
    final missingPadding = (4 - (base64String.length % 4)) % 4;
    return base64String + ('=' * missingPadding);
  }
}
