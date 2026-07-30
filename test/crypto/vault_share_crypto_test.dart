import 'package:flutter_test/flutter_test.dart';

import 'package:folio/crypto/vault_share_crypto.dart';

void main() {
  test('vault share wrap/unwrap round-trip', () async {
    final key = List<int>.generate(32, (i) => i + 1);
    const code = 'ABCD234567';
    const owner = 'owner1';
    const vault = 'vault1';
    final wrapped = await VaultShareCrypto.wrapKeyB64(
      keyBytes: key,
      shareCode: code,
      ownerUid: owner,
      vaultId: vault,
    );
    expect(wrapped, isNotEmpty);
    final opened = await VaultShareCrypto.unwrapKeyB64(
      wrappedB64: wrapped,
      shareCode: code.toLowerCase(),
      ownerUid: owner,
      vaultId: vault,
    );
    expect(opened, key);
  });

  test('wrong share code fails', () async {
    final key = List<int>.generate(32, (i) => 7);
    final wrapped = await VaultShareCrypto.wrapKeyB64(
      keyBytes: key,
      shareCode: 'RIGHTCODE1',
      ownerUid: 'o',
      vaultId: 'v',
    );
    expect(
      () => VaultShareCrypto.unwrapKeyB64(
        wrappedB64: wrapped,
        shareCode: 'WRONGCODE1',
        ownerUid: 'o',
        vaultId: 'v',
      ),
      throwsA(isA<VaultShareCryptoException>()),
    );
  });

  test('normalize share code', () {
    expect(VaultShareCrypto.normalizeShareCode(' ab cd '), 'ABCD');
  });
}
