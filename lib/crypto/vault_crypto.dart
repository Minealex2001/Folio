import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/errors/folio_exception.dart';

/// Argon2id + AES-256-GCM for Folio vault (DEK wrapping and payload encryption).
class VaultCrypto {
  VaultCrypto._();

  static final _random = Random.secure();

  /// Parámetros Argon2id "legacy" (perfil mínimo de OWASP) — usados para
  /// desenvolver blobs creados antes de que existiera el byte de versión.
  /// Nunca se usan para envolver nada nuevo.
  static final Argon2id _argon2Legacy = Argon2id(
    parallelism: 1,
    memory: 19456,
    iterations: 2,
    hashLength: 32,
  );

  /// Parámetros Argon2id "v1" (perfil moderado de OWASP) — usados para todo
  /// blob creado entre la introducción del versionado y la introducción de
  /// `_argon2V2`. Ya no se usan para envolver nada nuevo, pero siguen
  /// leyéndose vía `unwrapDek`.
  static final Argon2id _argon2V1 = Argon2id(
    parallelism: 1,
    memory: 47104,
    iterations: 3,
    hashLength: 32,
  );

  /// Parámetros Argon2id "v2" — perfil endurecido, usado para todo blob
  /// nuevo desde este cambio (migración transparente de vaults antiguos).
  static final Argon2id _argon2V2 = Argon2id(
    parallelism: 1,
    memory: 65536,
    iterations: 4,
    hashLength: 32,
  );

  static final AesGcm _aes = AesGcm.with256bits();

  static const int saltLength = 16;
  static const int dekLength = 32;
  static const int nonceLength = 12;

  /// Byte de versión que antepone `wrapDek` a todo blob nuevo. Los blobs
  /// creados antes de este cambio no llevan este byte (formato "legacy").
  static const int _currentWrapVersion = 2;

  /// Versión de formato de envoltorio que usa todo blob nuevo cuando no se
  /// pide explícitamente otra. Expuesta para que `VaultRepository` pueda
  /// decidir si un `vault.keys` existente necesita re-envolverse, sin
  /// duplicar la constante.
  static int get currentWrapVersion => _currentWrapVersion;

  /// Perfil Argon2id "Balanceado": rápido, el histórico antes de introducir
  /// el perfil reforzado.
  static const int profileBalanced = 1;

  /// Perfil Argon2id "Reforzado": más lento de derivar, más resistente a
  /// fuerza bruta.
  static const int profileHardened = 2;

  static Argon2id _argon2ForVersion(int version) {
    switch (version) {
      case 2:
        return _argon2V2;
      case 1:
        return _argon2V1;
      default:
        return _argon2Legacy;
    }
  }

  /// Longitud fija de un blob "legacy" (sin byte de versión): el DEK
  /// envuelto siempre mide [dekLength] bytes, así que el ciphertext AES-GCM
  /// mide lo mismo y el tamaño total es constante.
  static const int _legacyWrapLength = saltLength + nonceLength + dekLength + 16;

  /// Determina la versión de formato de [wrapped] mirando solo su longitud
  /// (y, si aplica, el byte de versión) — sin derivar ninguna clave ni
  /// necesitar la contraseña. Útil para decidir si hace falta migrar un
  /// `vault.keys` existente.
  static int wrapVersion(List<int> wrapped) {
    if (wrapped.length == _legacyWrapLength) return 0;
    if (wrapped.length == _legacyWrapLength + 1) return wrapped[0];
    throw VaultCryptoException('Datos de clave corruptos');
  }

  static Uint8List randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }

  static Future<SecretKey> deriveKekFromPassword({
    required String password,
    required List<int> salt,
    int version = 0,
  }) async {
    return _argon2ForVersion(version).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Returns [version(1)][salt (16)][nonce (12)][ciphertext+mac] wrapping [dek].
  /// Todo blob nuevo lleva el byte de versión. Por defecto usa el perfil
  /// Argon2id más duro (`_currentWrapVersion`); pasar [version] explícito
  /// (p. ej. `profileBalanced`) para que el llamador elija el perfil (p. ej.
  /// el usuario elige "Balanceado" al crear la libreta). Los blobs "legacy"
  /// (sin byte de versión, de antes de este cambio) se siguen leyendo
  /// correctamente vía `unwrapDek`, pero nunca se vuelven a escribir con los
  /// parámetros antiguos.
  static Future<Uint8List> wrapDek({
    required List<int> dek,
    required String password,
    List<int>? salt,
    int? version,
  }) async {
    final v = version ?? _currentWrapVersion;
    final s = salt != null ? Uint8List.fromList(salt) : randomBytes(saltLength);
    final kek = await deriveKekFromPassword(password: password, salt: s, version: v);
    final nonce = randomBytes(nonceLength);
    final box = await _aes.encrypt(dek, secretKey: kek, nonce: nonce);
    final out = BytesBuilder(copy: false);
    out.addByte(v);
    out.add(s);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.takeBytes();
  }

  static Future<Uint8List> unwrapDek({
    required List<int> wrapped,
    required String password,
  }) async {
    // Intenta primero el formato versionado (nuevo); si falla (MAC inválido,
    // longitud insuficiente, etc.) cae al formato legacy (sin byte de
    // versión, parámetros Argon2id antiguos) para no romper vaults ya
    // existentes creados antes de este cambio.
    try {
      return await _unwrapDekVersioned(wrapped: wrapped, password: password);
    } on VaultCryptoException {
      return await _unwrapDekLegacy(wrapped: wrapped, password: password);
    }
  }

  static Future<Uint8List> _unwrapDekVersioned({
    required List<int> wrapped,
    required String password,
  }) async {
    const headerLength = 1;
    if (wrapped.length < headerLength + saltLength + nonceLength + 16) {
      throw VaultCryptoException('Datos de clave corruptos');
    }
    final version = wrapped[0];
    // Acepta cualquier versión conocida hasta la actual (1 = perfil antiguo
    // moderado, 2 = perfil endurecido), no solo la más reciente — de lo
    // contrario un blob v1 caería al parser legacy y trataría su byte de
    // versión como el primer byte de la sal, corrompiéndola.
    if (version < 1 || version > _currentWrapVersion) {
      throw VaultCryptoException('Versión de clave desconocida');
    }
    final body = wrapped.sublist(headerLength);
    return _unwrapDekBody(body: body, password: password, version: version);
  }

  static Future<Uint8List> _unwrapDekLegacy({
    required List<int> wrapped,
    required String password,
  }) async {
    if (wrapped.length < saltLength + nonceLength + 16) {
      throw VaultCryptoException('Contraseña incorrecta o datos dañados');
    }
    return _unwrapDekBody(body: wrapped, password: password, version: 0);
  }

  static Future<Uint8List> _unwrapDekBody({
    required List<int> body,
    required String password,
    required int version,
  }) async {
    final s = body.sublist(0, saltLength);
    final nonce = body.sublist(saltLength, saltLength + nonceLength);
    final macStart = body.length - 16;
    final cipher = body.sublist(saltLength + nonceLength, macStart);
    final mac = Mac(body.sublist(macStart));
    final kek = await deriveKekFromPassword(password: password, salt: s, version: version);
    try {
      final clear = await _aes.decrypt(
        SecretBox(cipher, nonce: nonce, mac: mac),
        secretKey: kek,
      );
      return Uint8List.fromList(clear);
    } on Object {
      throw VaultCryptoException('Contraseña incorrecta o datos dañados');
    }
  }

  /// Encrypt [plain] with DEK. Format: [nonce 12][cipher][mac 16]
  static Future<Uint8List> encryptPayload({
    required List<int> plain,
    required SecretKey dek,
  }) async {
    final nonce = randomBytes(nonceLength);
    final box = await _aes.encrypt(plain, secretKey: dek, nonce: nonce);
    final out = BytesBuilder(copy: false);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.takeBytes();
  }

  /// Cifrado determinístico para blobs de copia incremental en la nube: mismo
  /// plaintext y misma base de nonce → mismo ciphertext (deduplicación en Storage).
  /// SEGURIDAD: [nonceBasis] DEBE derivarse del contenido de [plain] (p. ej. su
  /// hash), no solo de un rol/ruta estático — de lo contrario, dos llamadas con
  /// el mismo [dek] y el mismo [nonceBasis] pero [plain] distinto reutilizan
  /// nonce bajo AES-GCM, lo que permite forjar blobs auténticos falsos. Ver
  /// `cloudPackEncryptPlainBlob` para la construcción correcta (basis = rol +
  /// hash del contenido).
  static Future<Uint8List> encryptPayloadDeterministicPack({
    required List<int> plain,
    required SecretKey dek,
    required List<int> nonceBasis,
  }) async {
    final basisHash = await Sha256().hash(nonceBasis);
    final nonce = Uint8List.fromList(basisHash.bytes.sublist(0, nonceLength));
    final box = await _aes.encrypt(plain, secretKey: dek, nonce: nonce);
    final out = BytesBuilder(copy: false);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.takeBytes();
  }

  static Future<Uint8List> decryptPayload({
    required List<int> blob,
    required SecretKey dek,
  }) async {
    if (blob.length < nonceLength + 16) {
      throw VaultCryptoException('Libreta corrupta');
    }
    final nonce = blob.sublist(0, nonceLength);
    final macStart = blob.length - 16;
    final cipher = blob.sublist(nonceLength, macStart);
    final mac = Mac(blob.sublist(macStart));
    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: mac),
      secretKey: dek,
    );
    return Uint8List.fromList(clear);
  }

  static Future<SecretKey> dekFromBytes(List<int> bytes) async {
    if (bytes.length != dekLength) {
      throw VaultCryptoException('DEK inválida');
    }
    return SecretKey(bytes);
  }
}

class VaultCryptoException extends FolioException {
  VaultCryptoException(super.message);
}
