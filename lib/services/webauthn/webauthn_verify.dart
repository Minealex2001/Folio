import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:pointycastle/export.dart';

// `package:cbor/cbor.dart` exports both the advanced API's `cbor` (a
// `CborCodec`, decodes to `CborValue`) and the simple API's `cbor` (a
// `CborSimpleCodec`, decodes to plain Dart objects) under the same name —
// use the class directly instead of the ambiguous top-level constant.
const _simpleCbor = CborSimpleCodec();

/// Clave pública WebAuthn (COSE) extraída del `attestationObject` en el
/// registro de una passkey, guardada junto a la credencial para poder
/// verificar la firma del autenticador en logins posteriores. Sin esto, el
/// RP local solo puede comparar campos JSON (challenge/origin/credentialId),
/// sin ninguna garantía criptográfica de que la firma provenga del
/// autenticador correcto.
class WebAuthnPublicKey {
  const WebAuthnPublicKey({required this.alg, this.x, this.y, this.n, this.e});

  /// Identificador COSE del algoritmo de firma (-7 = ES256, -257 = RS256).
  final int alg;

  /// EC2 (P-256): coordenadas del punto público (32 bytes cada una).
  final Uint8List? x;
  final Uint8List? y;

  /// RSA: módulo y exponente público.
  final Uint8List? n;
  final Uint8List? e;

  Map<String, Object?> toJson() => {
        'alg': alg,
        if (x != null) 'x': base64Encode(x!),
        if (y != null) 'y': base64Encode(y!),
        if (n != null) 'n': base64Encode(n!),
        if (e != null) 'e': base64Encode(e!),
      };

  static WebAuthnPublicKey? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final alg = json['alg'];
    if (alg is! int) return null;
    Uint8List? decodeField(String key) {
      final v = json[key];
      if (v is! String || v.isEmpty) return null;
      try {
        return base64Decode(v);
      } catch (_) {
        return null;
      }
    }

    return WebAuthnPublicKey(
      alg: alg,
      x: decodeField('x'),
      y: decodeField('y'),
      n: decodeField('n'),
      e: decodeField('e'),
    );
  }
}

class WebAuthnVerifyException implements Exception {
  const WebAuthnVerifyException(this.message);
  final String message;
  @override
  String toString() => 'WebAuthnVerifyException: $message';
}

/// Extrae la clave pública COSE del `attestationObject` de una respuesta
/// `navigator.credentials.create()`.
WebAuthnPublicKey parsePublicKeyFromAttestationObject(Uint8List attestationObject) {
  final decoded = _simpleCbor.decode(attestationObject);
  if (decoded is! Map) {
    throw const WebAuthnVerifyException('attestationObject inválido');
  }
  final authData = decoded['authData'];
  if (authData is! List<int>) {
    throw const WebAuthnVerifyException('attestationObject sin authData');
  }
  return _parsePublicKeyFromAuthData(Uint8List.fromList(authData));
}

WebAuthnPublicKey _parsePublicKeyFromAuthData(Uint8List authData) {
  const rpIdHashLen = 32;
  const flagsLen = 1;
  const signCountLen = 4;
  const aaguidLen = 16;
  const credIdLenFieldLen = 2;
  const attestedCredentialDataFlag = 0x40;

  if (authData.length < rpIdHashLen + flagsLen + signCountLen) {
    throw const WebAuthnVerifyException('authData truncado');
  }
  final flags = authData[rpIdHashLen];
  if (flags & attestedCredentialDataFlag == 0) {
    throw const WebAuthnVerifyException(
      'authData sin datos de credencial atestiguada (registro inválido)',
    );
  }
  var offset = rpIdHashLen + flagsLen + signCountLen + aaguidLen;
  if (offset + credIdLenFieldLen > authData.length) {
    throw const WebAuthnVerifyException('authData truncado (credentialId)');
  }
  final credIdLen = (authData[offset] << 8) | authData[offset + 1];
  offset += credIdLenFieldLen + credIdLen;
  if (offset >= authData.length) {
    throw const WebAuthnVerifyException('authData sin clave pública COSE');
  }

  final coseKeyTail = authData.sublist(offset);
  final coseKeyValue = _decodeFirstCborValue(coseKeyTail);
  final coseMap = coseKeyValue.toObject();
  if (coseMap is! Map) {
    throw const WebAuthnVerifyException('COSE key inválida');
  }

  final kty = coseMap[1];
  final alg = coseMap[3];
  if (alg is! int) {
    throw const WebAuthnVerifyException('COSE key sin alg válido');
  }
  if (kty == 2) {
    final x = coseMap[-2];
    final y = coseMap[-3];
    if (x is! List<int> || y is! List<int>) {
      throw const WebAuthnVerifyException('COSE EC2 sin x/y');
    }
    return WebAuthnPublicKey(alg: alg, x: Uint8List.fromList(x), y: Uint8List.fromList(y));
  }
  if (kty == 3) {
    final n = coseMap[-1];
    final e = coseMap[-2];
    if (n is! List<int> || e is! List<int>) {
      throw const WebAuthnVerifyException('COSE RSA sin n/e');
    }
    return WebAuthnPublicKey(alg: alg, n: Uint8List.fromList(n), e: Uint8List.fromList(e));
  }
  throw WebAuthnVerifyException('Tipo de clave COSE no soportado (kty=$kty)');
}

/// Decodifica el primer valor CBOR de una secuencia, tolerando bytes
/// sobrantes al final (p. ej. extensiones tras la clave pública en
/// `authData`) — a diferencia de `cbor.decode`, que exige un único valor.
CborValue _decodeFirstCborValue(List<int> bytes) {
  CborValue? first;
  final sink = ChunkedConversionSink<CborValue>.withCallback((values) {
    if (values.isNotEmpty) first = values.first;
  });
  const CborDecoder().startChunkedConversion(sink)
    ..add(bytes)
    ..close();
  if (first == null) {
    throw const WebAuthnVerifyException('No se encontró ningún valor CBOR');
  }
  return first!;
}

/// Verifica que [derSignature] firma [signedData] (`authenticatorData ++
/// SHA-256(clientDataJSON)`) bajo [publicKey]. Soporta ES256 (EC2/P-256,
/// firma DER) y RS256 (RSASSA-PKCS1-v1_5 SHA-256), los dos algoritmos que
/// Folio ofrece en `pubKeyCredParams` al registrar una passkey.
bool verifyWebAuthnSignature({
  required WebAuthnPublicKey publicKey,
  required Uint8List signedData,
  required Uint8List derSignature,
}) {
  switch (publicKey.alg) {
    case -7: // ES256
      return _verifyEcdsaP256(
        publicKey: publicKey,
        signedData: signedData,
        derSignature: derSignature,
      );
    case -257: // RS256
      return _verifyRsaPkcs1Sha256(
        publicKey: publicKey,
        signedData: signedData,
        signature: derSignature,
      );
    default:
      throw WebAuthnVerifyException('Algoritmo COSE no soportado: ${publicKey.alg}');
  }
}

bool _verifyEcdsaP256({
  required WebAuthnPublicKey publicKey,
  required Uint8List signedData,
  required Uint8List derSignature,
}) {
  final x = publicKey.x;
  final y = publicKey.y;
  if (x == null || y == null) {
    throw const WebAuthnVerifyException('Clave EC2 incompleta');
  }
  final params = ECDomainParameters('prime256v1');
  final q = params.curve.createPoint(_bigIntFromBytes(x), _bigIntFromBytes(y));
  final pubKey = ECPublicKey(q, params);
  final signature = _decodeDerEcdsaSignature(derSignature);
  final signer = ECDSASigner(SHA256Digest())
    ..init(false, PublicKeyParameter<ECPublicKey>(pubKey));
  try {
    return signer.verifySignature(signedData, signature);
  } on Object {
    return false;
  }
}

bool _verifyRsaPkcs1Sha256({
  required WebAuthnPublicKey publicKey,
  required Uint8List signedData,
  required Uint8List signature,
}) {
  final n = publicKey.n;
  final e = publicKey.e;
  if (n == null || e == null) {
    throw const WebAuthnVerifyException('Clave RSA incompleta');
  }
  final pubKey = RSAPublicKey(_bigIntFromBytes(n), _bigIntFromBytes(e));
  // OID DER de SHA-256, requerido por el DigestInfo de PKCS#1 v1.5.
  final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
    ..init(false, PublicKeyParameter<RSAPublicKey>(pubKey));
  try {
    return signer.verifySignature(signedData, RSASignature(signature));
  } on Object {
    return false;
  }
}

BigInt _bigIntFromBytes(List<int> bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

/// Decodifica una firma ECDSA en formato DER (`SEQUENCE { INTEGER r, INTEGER
/// s }`, tal como la entrega WebAuthn) en un [ECSignature].
ECSignature _decodeDerEcdsaSignature(Uint8List der) {
  var offset = 0;
  if (der.isEmpty || der[offset] != 0x30) {
    throw const WebAuthnVerifyException('Firma DER inválida (no es SEQUENCE)');
  }
  offset++;
  final seqLen = _readDerLength(der, offset);
  offset += seqLen.$2;

  if (offset >= der.length || der[offset] != 0x02) {
    throw const WebAuthnVerifyException('Firma DER inválida (r no es INTEGER)');
  }
  offset++;
  final rLen = _readDerLength(der, offset);
  offset += rLen.$2;
  final r = _bigIntFromBytes(der.sublist(offset, offset + rLen.$1));
  offset += rLen.$1;

  if (offset >= der.length || der[offset] != 0x02) {
    throw const WebAuthnVerifyException('Firma DER inválida (s no es INTEGER)');
  }
  offset++;
  final sLen = _readDerLength(der, offset);
  offset += sLen.$2;
  final s = _bigIntFromBytes(der.sublist(offset, offset + sLen.$1));

  return ECSignature(r, s);
}

/// Lee una longitud DER (forma corta o larga) empezando en [offset].
/// Devuelve (longitud, bytes consumidos por el campo de longitud).
(int, int) _readDerLength(Uint8List der, int offset) {
  if (offset >= der.length) {
    throw const WebAuthnVerifyException('Firma DER truncada');
  }
  final first = der[offset];
  if (first & 0x80 == 0) {
    return (first, 1);
  }
  final numBytes = first & 0x7F;
  if (numBytes == 0 || numBytes > 4 || offset + 1 + numBytes > der.length) {
    throw const WebAuthnVerifyException('Firma DER con longitud no soportada');
  }
  var length = 0;
  for (var i = 0; i < numBytes; i++) {
    length = (length << 8) | der[offset + 1 + i];
  }
  return (length, 1 + numBytes);
}
