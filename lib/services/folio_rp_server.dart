import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/vault_paths.dart';

/// Relying party **local** para passkeys (mismo enfoque que el ejemplo oficial de `passkeys`).
/// Solo metadatos de credencial; no contiene el contenido del cofre.
class FolioRpUser {
  FolioRpUser({
    required this.name,
    required this.id,
    this.credentialID,
    this.transports = const [],
  });

  final String name;
  final String id;
  String? credentialID;
  List<String> transports;

  Map<String, dynamic> toJson() => {
    'name': name,
    'id': id,
    'credentialID': credentialID,
    'transports': transports,
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
    );
  }
}

/// ID de relying party. En web sería el host; en escritorio/móvil debe ser coherente con la plataforma.
String get folioRpId {
  if (kIsWeb) {
    return 'localhost';
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
    final f = await VaultPaths.rpStatePath();
    if (!f.existsSync()) return;
    try {
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
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
    final f = await VaultPaths.rpStatePath();
    final users = <String, dynamic>{};
    for (final e in _users.entries) {
      users[e.key] = e.value.toJson();
    }
    await f.writeAsString(jsonEncode({'users': users}));
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

  Future<void> finishPasskeyRegister({required String response}) async {
    final responseMap = jsonDecode(response) as Map<String, dynamic>;
    final responseData = responseMap['response'] as Map<String, dynamic>;
    final clientDataJSON = responseData['clientDataJSON'] as String;
    final id = responseMap['id'] as String;
    final transports = responseData['transports'] as List<dynamic>?;

    final raw = addBase64Padding(clientDataJSON);
    final clientData =
        jsonDecode(String.fromCharCodes(base64.decode(raw)))
            as Map<String, dynamic>;

    final challenge = clientData['challenge'] as String;
    final user = _inFlight[challenge];
    if (user == null) {
      throw StateError('Estado passkey inválido');
    }

    user
      ..credentialID = id
      ..transports = (transports?.isEmpty ?? true)
          ? ['internal', 'hybrid']
          : transports!.map((e) => e as String).toList();
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

    final raw = addBase64Padding(clientDataJSON);
    final clientData =
        jsonDecode(String.fromCharCodes(base64.decode(raw)))
            as Map<String, dynamic>;

    final challenge = clientData['challenge'] as String;
    final user = _inFlight[challenge];
    if (user == null) {
      throw StateError('Estado passkey inválido');
    }
    _inFlight.remove(challenge);
  }

  Future<void> clearPasskey() async {
    _users.remove(defaultUserName);
    _inFlight.clear();
    final f = await VaultPaths.rpStatePath();
    if (f.existsSync()) {
      await f.delete();
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
