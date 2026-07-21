import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cbor/cbor.dart' show CborSimpleCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/services/webauthn/webauthn_verify.dart';
import 'package:pointycastle/export.dart';

Uint8List _bigIntToBytes(BigInt value, int length) {
  final out = Uint8List(length);
  var v = value;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return out;
}

/// Codifica una firma ECDSA (r,s) en DER, como la produce un autenticador
/// WebAuthn real.
Uint8List _encodeDerEcdsaSignature(ECSignature sig) {
  List<int> encodeInt(BigInt v) {
    var bytes = v.toRadixString(16);
    if (bytes.length.isOdd) bytes = '0$bytes';
    var b = List<int>.generate(
      bytes.length ~/ 2,
      (i) => int.parse(bytes.substring(i * 2, i * 2 + 2), radix: 16),
    );
    if (b.isNotEmpty && b[0] & 0x80 != 0) {
      b = [0, ...b];
    }
    return [0x02, b.length, ...b];
  }

  final rEnc = encodeInt(sig.r);
  final sEnc = encodeInt(sig.s);
  final body = [...rEnc, ...sEnc];
  return Uint8List.fromList([0x30, body.length, ...body]);
}

/// Construye un `authData` WebAuthn mínimo (rpIdHash + flags + signCount +
/// aaguid + credentialId + COSE public key) para pruebas.
Uint8List _buildAuthData({
  required Uint8List credentialId,
  required Map<int, Object?> coseKey,
}) {
  final rpIdHash = Uint8List(32); // contenido irrelevante para este test
  const flags = 0x40; // AT: attested credential data presente
  final signCount = Uint8List(4);
  final aaguid = Uint8List(16);
  final credIdLen = Uint8List(2)
    ..[0] = (credentialId.length >> 8) & 0xff
    ..[1] = credentialId.length & 0xff;
  final coseKeyBytes = const CborSimpleCodec().encode(coseKey);

  return Uint8List.fromList([
    ...rpIdHash,
    flags,
    ...signCount,
    ...aaguid,
    ...credIdLen,
    ...credentialId,
    ...coseKeyBytes,
  ]);
}

void main() {
  group('ES256 (EC2/P-256)', () {
    late ECPrivateKey privateKey;
    late ECPublicKey publicKey;
    late ECDomainParameters params;

    setUp(() {
      params = ECDomainParameters('prime256v1');
      final keyGen = ECKeyGenerator()
        ..init(
          ParametersWithRandom(
            ECKeyGeneratorParameters(params),
            _testSecureRandom(),
          ),
        );
      final pair = keyGen.generateKeyPair();
      privateKey = pair.privateKey;
      publicKey = pair.publicKey;
    });

    WebAuthnPublicKey webAuthnPublicKey() {
      final q = publicKey.Q!;
      return WebAuthnPublicKey(
        alg: -7,
        x: _bigIntToBytes(q.x!.toBigInteger()!, 32),
        y: _bigIntToBytes(q.y!.toBigInteger()!, 32),
      );
    }

    Uint8List sign(Uint8List message) {
      final signer = ECDSASigner(SHA256Digest())
        ..init(
          true,
          ParametersWithRandom(
            PrivateKeyParameter<ECPrivateKey>(privateKey),
            _testSecureRandom(),
          ),
        );
      final sig = signer.generateSignature(message) as ECSignature;
      return _encodeDerEcdsaSignature(sig);
    }

    test('verifies a genuine signature', () {
      final message = utf8.encode('authData || sha256(clientDataJSON)');
      final der = sign(Uint8List.fromList(message));
      final ok = verifyWebAuthnSignature(
        publicKey: webAuthnPublicKey(),
        signedData: Uint8List.fromList(message),
        derSignature: der,
      );
      expect(ok, isTrue);
    });

    test('rejects a signature over a different message', () {
      final message = utf8.encode('original message');
      final der = sign(Uint8List.fromList(message));
      final ok = verifyWebAuthnSignature(
        publicKey: webAuthnPublicKey(),
        signedData: utf8.encode('tampered message'),
        derSignature: der,
      );
      expect(ok, isFalse);
    });

    test('rejects a signature from a different key pair', () {
      final message = utf8.encode('authData || clientDataHash');
      final der = sign(Uint8List.fromList(message));

      final otherKeyGen = ECKeyGenerator()
        ..init(
          ParametersWithRandom(
            ECKeyGeneratorParameters(params),
            _testSecureRandom(),
          ),
        );
      final otherPair = otherKeyGen.generateKeyPair();
      final otherPublic = otherPair.publicKey;
      final otherQ = otherPublic.Q!;
      final otherWebAuthnKey = WebAuthnPublicKey(
        alg: -7,
        x: _bigIntToBytes(otherQ.x!.toBigInteger()!, 32),
        y: _bigIntToBytes(otherQ.y!.toBigInteger()!, 32),
      );

      final ok = verifyWebAuthnSignature(
        publicKey: otherWebAuthnKey,
        signedData: Uint8List.fromList(message),
        derSignature: der,
      );
      expect(ok, isFalse);
    });

    test('parsePublicKeyFromAttestationObject round-trips the COSE EC2 key', () {
      final q = publicKey.Q!;
      final x = _bigIntToBytes(q.x!.toBigInteger()!, 32);
      final y = _bigIntToBytes(q.y!.toBigInteger()!, 32);
      final credentialId = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final authData = _buildAuthData(
        credentialId: credentialId,
        coseKey: {1: 2, 3: -7, -1: 1, -2: x, -3: y},
      );
      final attestationObject = const CborSimpleCodec().encode({
        'fmt': 'none',
        'attStmt': <Object?, Object?>{},
        'authData': authData,
      });

      final parsed = parsePublicKeyFromAttestationObject(
        Uint8List.fromList(attestationObject),
      );
      expect(parsed.alg, equals(-7));
      expect(parsed.x, equals(x));
      expect(parsed.y, equals(y));
    });
  });
}

SecureRandom _testSecureRandom() {
  final rnd = Random.secure();
  final seed = Uint8List(32);
  for (var i = 0; i < seed.length; i++) {
    seed[i] = rnd.nextInt(256);
  }
  return FortunaRandom()..seed(KeyParameter(seed));
}
