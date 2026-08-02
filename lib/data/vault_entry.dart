/// Ownership / sharing metadata for a vault in the local registry.
enum VaultOwnership { owned, shared }

/// Entrada mostrada en la papelera de libretas. [hasLocalCopy] es false para
/// libretas borradas en otro dispositivo que este nunca llegó a materializar
/// ("fantasma"): solo se conocen por lo que devuelve la nube.
class VaultTrashEntry {
  const VaultTrashEntry({
    required this.vaultId,
    required this.displayName,
    required this.trashedAt,
    required this.hasLocalCopy,
  });

  final String vaultId;
  final String displayName;
  final DateTime trashedAt;
  final bool hasLocalCopy;
}

/// Entrada del registro de libretas (metadatos en prefs, datos en disco por [id]).
class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.displayName,
    required this.createdAtMs,
    this.ownership = VaultOwnership.owned,
    this.ownerUid,
    this.role,
    this.ownerDisplayName,
    this.trashedAt,
  });

  final String id;
  final String displayName;
  final int createdAtMs;

  /// Owned by this account, or shared with me by another user.
  final VaultOwnership ownership;

  /// Cloud owner uid when [ownership] is [VaultOwnership.shared].
  final String? ownerUid;

  /// `editor` when shared.
  final String? role;

  final String? ownerDisplayName;

  /// Cuándo se movió a la papelera. `null` si está activa.
  final DateTime? trashedAt;

  bool get isShared => ownership == VaultOwnership.shared;

  bool get canDelete => !isShared;

  bool get isTrashed => trashedAt != null;

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'createdAtMs': createdAtMs,
    if (ownership != VaultOwnership.owned) 'ownership': ownership.name,
    if (ownerUid != null && ownerUid!.isNotEmpty) 'ownerUid': ownerUid,
    if (role != null && role!.isNotEmpty) 'role': role,
    if (ownerDisplayName != null && ownerDisplayName!.isNotEmpty)
      'ownerDisplayName': ownerDisplayName,
    if (trashedAt != null) 'trashedAtMs': trashedAt!.millisecondsSinceEpoch,
  };

  factory VaultEntry.fromJson(Map<String, Object?> j) {
    final ownershipRaw = '${j['ownership'] ?? 'owned'}';
    final ownership = ownershipRaw == 'shared'
        ? VaultOwnership.shared
        : VaultOwnership.owned;
    final trashedAtMs = j['trashedAtMs'] as num?;
    return VaultEntry(
      id: j['id']! as String,
      displayName: j['displayName']! as String,
      createdAtMs: (j['createdAtMs'] as num).toInt(),
      ownership: ownership,
      ownerUid: j['ownerUid'] as String?,
      role: j['role'] as String?,
      ownerDisplayName: j['ownerDisplayName'] as String?,
      trashedAt: trashedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(trashedAtMs.toInt()),
    );
  }

  VaultEntry copyWith({
    String? displayName,
    VaultOwnership? ownership,
    String? ownerUid,
    String? role,
    String? ownerDisplayName,
    DateTime? trashedAt,
    bool clearTrashedAt = false,
  }) {
    return VaultEntry(
      id: id,
      displayName: displayName ?? this.displayName,
      createdAtMs: createdAtMs,
      ownership: ownership ?? this.ownership,
      ownerUid: ownerUid ?? this.ownerUid,
      role: role ?? this.role,
      ownerDisplayName: ownerDisplayName ?? this.ownerDisplayName,
      trashedAt: clearTrashedAt ? null : (trashedAt ?? this.trashedAt),
    );
  }
}
