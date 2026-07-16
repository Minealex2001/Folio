import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Criptografía del canal de sincronización LAN entre dispositivos.
///
/// Cada dispositivo mantiene un par de claves X25519 persistente. Durante el
/// emparejamiento se intercambian y fijan (trust-on-first-use) las claves
/// públicas; después, cada transferencia de snapshot se cifra y autentica con
/// AES-256-GCM usando una clave derivada (HKDF-SHA256) del secreto compartido
/// X25519. Un host no emparejado no puede solicitar ni leer snapshots.
class DeviceSyncCrypto {
  DeviceSyncCrypto({FlutterSecureStorage? storage})
    : _secure =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static final X25519 _x25519 = X25519();
  static final AesGcm _aes = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final Random _random = Random.secure();

  static const String _seedKey = 'folio_device_sync_x25519_seed_b64_v1';
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  final FlutterSecureStorage _secure;
  SimpleKeyPair? _keyPair;
  String? _publicKeyB64;
  final Map<String, SecretKey> _sharedKeyCache = {};

  /// Clave pública local en base64, disponible tras [ensureKeyPair].
  String? get publicKeyB64 => _publicKeyB64;

  Future<void> ensureKeyPair() async {
    if (_keyPair != null) return;
    List<int>? seed = await _readSeed();
    if (seed == null || seed.length != 32) {
      final generated = await _x25519.newKeyPair();
      seed = await generated.extractPrivateKeyBytes();
      await _writeSeed(seed);
    }
    final keyPair = await _x25519.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    _keyPair = keyPair;
    _publicKeyB64 = base64Encode(publicKey.bytes);
  }

  Future<List<int>?> _readSeed() async {
    try {
      final b64 = await _secure.read(key: _seedKey);
      if (b64 != null && b64.isNotEmpty) return base64Decode(b64);
    } catch (_) {
      // Continúa con el fallback.
    }
    try {
      final p = await SharedPreferences.getInstance();
      final b64 = p.getString(_seedKey);
      if (b64 != null && b64.isNotEmpty) return base64Decode(b64);
    } catch (_) {}
    return null;
  }

  Future<void> _writeSeed(List<int> seed) async {
    final b64 = base64Encode(seed);
    try {
      await _secure.write(key: _seedKey, value: b64);
      return;
    } catch (_) {
      // Fallback: la clave debe ser estable entre reinicios para que el
      // anclaje de emparejamiento no se rompa; prefs es mejor que regenerar.
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_seedKey, b64);
    } catch (_) {}
  }

  /// Deriva (y cachea) la clave simétrica de canal con un peer.
  Future<SecretKey> sharedKeyWith(String peerPublicKeyB64) async {
    final cached = _sharedKeyCache[peerPublicKeyB64];
    if (cached != null) return cached;
    final keyPair = _keyPair;
    if (keyPair == null) {
      throw StateError('DeviceSyncCrypto.ensureKeyPair() no fue invocado');
    }
    final peerPublic = SimplePublicKey(
      base64Decode(peerPublicKeyB64),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: peerPublic,
    );
    final derived = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: const <int>[],
      info: utf8.encode('FolioDeviceSyncChannel/v1'),
    );
    final key = SecretKey(derived.bytes);
    _sharedKeyCache[peerPublicKeyB64] = key;
    return key;
  }

  /// Formato: [nonce 12][cipher][mac 16], en base64.
  Future<String> sealB64(List<int> plain, SecretKey key) async {
    final nonce = Uint8List(_nonceLength);
    for (var i = 0; i < _nonceLength; i++) {
      nonce[i] = _random.nextInt(256);
    }
    final box = await _aes.encrypt(plain, secretKey: key, nonce: nonce);
    final out = BytesBuilder(copy: false)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return base64Encode(out.takeBytes());
  }

  /// Abre un blob sellado con [sealB64]. Lanza si la autenticación falla.
  Future<Uint8List> openB64(String sealedB64, SecretKey key) async {
    final blob = base64Decode(sealedB64);
    if (blob.length < _nonceLength + _macLength) {
      throw const FormatException('Blob cifrado incompleto');
    }
    final nonce = blob.sublist(0, _nonceLength);
    final macStart = blob.length - _macLength;
    final cipher = blob.sublist(_nonceLength, macStart);
    final mac = Mac(blob.sublist(macStart));
    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: mac),
      secretKey: key,
    );
    return Uint8List.fromList(clear);
  }

  /// Envuelve [data] con marca de tiempo para poder rechazar reenvíos tardíos.
  static Uint8List packTimestampEnvelope(List<int> data) {
    final header = ByteData(8)
      ..setInt64(0, DateTime.now().millisecondsSinceEpoch);
    final out = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(data);
    return out.takeBytes();
  }

  /// Extrae el contenido de un sobre creado con [packTimestampEnvelope].
  /// Devuelve `null` si el sobre es inválido o su marca supera [maxAge].
  static Uint8List? unpackTimestampEnvelope(
    Uint8List envelope, {
    Duration maxAge = const Duration(minutes: 10),
  }) {
    if (envelope.length < 8) return null;
    final ts = ByteData.sublistView(envelope, 0, 8).getInt64(0);
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((now - ts).abs() > maxAge.inMilliseconds) return null;
    return Uint8List.sublistView(envelope, 8);
  }
}
