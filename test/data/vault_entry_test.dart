import 'package:flutter_test/flutter_test.dart';

import 'package:folio/data/vault_entry.dart';

void main() {
  test('owned vault can be deleted', () {
    const e = VaultEntry(
      id: 'a',
      displayName: 'Mine',
      createdAtMs: 1,
    );
    expect(e.canDelete, isTrue);
    expect(e.isShared, isFalse);
  });

  test('shared vault cannot be deleted', () {
    const e = VaultEntry(
      id: 'b',
      displayName: 'Shared',
      createdAtMs: 1,
      ownership: VaultOwnership.shared,
      ownerUid: 'owner',
      role: 'editor',
    );
    expect(e.canDelete, isFalse);
    expect(e.isShared, isTrue);
  });

  test('round-trip json preserves ownership', () {
    const e = VaultEntry(
      id: 'c',
      displayName: 'S',
      createdAtMs: 42,
      ownership: VaultOwnership.shared,
      ownerUid: 'u1',
      role: 'editor',
      ownerDisplayName: 'Ana',
    );
    final again = VaultEntry.fromJson(e.toJson());
    expect(again.ownership, VaultOwnership.shared);
    expect(again.ownerUid, 'u1');
    expect(again.canDelete, isFalse);
  });

  test('round-trip json preserves trashedAt', () {
    final trashedAt = DateTime.fromMillisecondsSinceEpoch(123456789);
    final e = VaultEntry(
      id: 'd',
      displayName: 'D',
      createdAtMs: 1,
      trashedAt: trashedAt,
    );
    expect(e.isTrashed, isTrue);

    final again = VaultEntry.fromJson(e.toJson());
    expect(again.isTrashed, isTrue);
    expect(again.trashedAt, trashedAt);
  });

  test('copyWith clearTrashedAt removes trashedAt', () {
    final e = VaultEntry(
      id: 'e',
      displayName: 'E',
      createdAtMs: 1,
      trashedAt: DateTime.now(),
    );
    final restored = e.copyWith(clearTrashedAt: true);
    expect(restored.isTrashed, isFalse);
    expect(restored.trashedAt, isNull);
  });
}
