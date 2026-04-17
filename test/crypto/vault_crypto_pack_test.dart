import 'package:flutter_test/flutter_test.dart';
import 'package:folio/crypto/vault_crypto.dart';

void main() {
  test('encryptPayloadDeterministicPack is stable for same input', () async {
    final dek = await VaultCrypto.dekFromBytes(List<int>.filled(32, 7));
    final plain = [1, 2, 3, 4, 5];
    final basis = [10, 20, 30];
    final a = await VaultCrypto.encryptPayloadDeterministicPack(
      plain: plain,
      dek: dek,
      nonceBasis: basis,
    );
    final b = await VaultCrypto.encryptPayloadDeterministicPack(
      plain: plain,
      dek: dek,
      nonceBasis: basis,
    );
    expect(a, equals(b));
    final clear = await VaultCrypto.decryptPayload(blob: a, dek: dek);
    expect(clear, equals(plain));
  });
}
