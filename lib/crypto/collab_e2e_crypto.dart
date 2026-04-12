import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Cifrado E2E para salas `collabRooms`: el backend solo ve blobs AES-GCM.
///
/// La clave de sala se envuelve con HKDF-SHA256 a partir del código de unión
/// (normalizado como en Cloud Functions) y el [roomId] como sal.
class CollabE2eCrypto {
  CollabE2eCrypto._();

  static final _random = Random.secure();
  static final AesGcm _aes = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  );

  static const int _nonceLength = 12;
  static const int _roomKeyLength = 32;
  static Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }

  /// Misma normalización que `normalizeCollabJoinCode` en Cloud Functions.
  static String normalizeJoinCode(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), '').trim();
  }

  static Future<SecretKey> _deriveWrapKey({
    required String joinCodeNormalized,
    required String roomId,
  }) async {
    final out = await _hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(joinCodeNormalized)),
      nonce: utf8.encode(roomId),
      info: utf8.encode('FolioCollabWrapKey/v1'),
    );
    return SecretKey(out.bytes);
  }

  /// Formato: [nonce 12][cipher][mac 16]
  static Future<Uint8List> _seal({
    required List<int> plain,
    required SecretKey key,
  }) async {
    final nonce = _randomBytes(_nonceLength);
    final box = await _aes.encrypt(plain, secretKey: key, nonce: nonce);
    final out = BytesBuilder(copy: false);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.takeBytes();
  }

  static Future<Uint8List> _open({
    required List<int> blob,
    required SecretKey key,
  }) async {
    if (blob.length < _nonceLength + 16) {
      throw CollabE2eException('Datos cifrados incompletos');
    }
    final nonce = blob.sublist(0, _nonceLength);
    final macStart = blob.length - 16;
    final cipher = blob.sublist(_nonceLength, macStart);
    final mac = Mac(blob.sublist(macStart));
    try {
      final clear = await _aes.decrypt(
        SecretBox(cipher, nonce: nonce, mac: mac),
        secretKey: key,
      );
      return Uint8List.fromList(clear);
    } on Object {
      throw CollabE2eException('No se pudo descifrar (código o sala incorrectos)');
    }
  }

  static Future<SecretKey> generateRoomKey() async {
    return SecretKey(_randomBytes(_roomKeyLength));
  }

  static Future<String> wrapRoomKeyB64({
    required SecretKey roomKey,
    required String joinCodeNormalized,
    required String roomId,
  }) async {
    final rk = await roomKey.extractBytes();
    if (rk.length != _roomKeyLength) {
      throw CollabE2eException('Clave de sala inválida');
    }
    final wrap = await _deriveWrapKey(
      joinCodeNormalized: joinCodeNormalized,
      roomId: roomId,
    );
    final sealed = await _seal(plain: rk, key: wrap);
    return base64Encode(sealed);
  }

  static Future<SecretKey> unwrapRoomKeyB64({
    required String wrappedB64,
    required String joinCodeNormalized,
    required String roomId,
  }) async {
    List<int> wrapped;
    try {
      wrapped = base64Decode(wrappedB64);
    } on Object {
      throw CollabE2eException('Clave envuelta inválida');
    }
    final wrap = await _deriveWrapKey(
      joinCodeNormalized: joinCodeNormalized,
      roomId: roomId,
    );
    final clear = await _open(blob: wrapped, key: wrap);
    if (clear.length != _roomKeyLength) {
      throw CollabE2eException('Clave de sala corrupta');
    }
    return SecretKey(clear);
  }

  static Future<String> encryptPagePayloadB64({
    required String title,
    required List<Map<String, dynamic>> blocksJson,
    required SecretKey roomKey,
  }) async {
    final payload = utf8.encode(
      jsonEncode({'title': title, 'blocks': blocksJson}),
    );
    final sealed = await _seal(plain: payload, key: roomKey);
    return base64Encode(sealed);
  }

  static Future<({String title, List<Map<String, dynamic>> blocks})>
      decryptPagePayloadB64({
    required String cipherB64,
    required SecretKey roomKey,
  }) async {
    List<int> blob;
    try {
      blob = base64Decode(cipherB64);
    } on Object {
      throw CollabE2eException('Contenido cifrado inválido');
    }
    final plain = await _open(blob: blob, key: roomKey);
    final obj = jsonDecode(utf8.decode(plain));
    if (obj is! Map) {
      throw CollabE2eException('Formato de página corrupto');
    }
    final m = Map<String, dynamic>.from(obj);
    final title = '${m['title'] ?? ''}';
    final rawBlocks = m['blocks'];
    if (rawBlocks is! List) {
      throw CollabE2eException('Bloques corruptos');
    }
    final blocks = rawBlocks
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return (title: title, blocks: blocks);
  }

  static Future<String> encryptChatMessageB64({
    required String authorName,
    required String text,
    required SecretKey roomKey,
  }) async {
    final payload = utf8.encode(
      jsonEncode({'n': authorName, 't': text}),
    );
    final sealed = await _seal(plain: payload, key: roomKey);
    return base64Encode(sealed);
  }

  static Future<({String authorName, String text})> decryptChatMessageB64({
    required String cipherB64,
    required SecretKey roomKey,
  }) async {
    List<int> blob;
    try {
      blob = base64Decode(cipherB64);
    } on Object {
      throw CollabE2eException('Mensaje cifrado inválido');
    }
    final plain = await _open(blob: blob, key: roomKey);
    final obj = jsonDecode(utf8.decode(plain));
    if (obj is! Map) {
      throw CollabE2eException('Mensaje corrupto');
    }
    final m = Map<String, dynamic>.from(obj);
    return (authorName: '${m['n'] ?? ''}', text: '${m['t'] ?? ''}');
  }
}

class CollabE2eException implements Exception {
  CollabE2eException(this.message);
  final String message;

  @override
  String toString() => message;
}
