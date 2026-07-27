package com.folio.backend.vault.dto;

import java.util.List;

public record FinalizeCloudPackRequest(
    String vaultId,
    String snapshotStoragePath,
    Long snapshotSizeBytes,
    String contentFingerprint,
    String oldSnapshotStoragePath,
    Long oldSnapshotSizeBytes,
    List<BlobSizeDto> newBlobs,
    List<BlobSizeDto> deleteBlobs,
    String cloudPackRestoreWrapB64,
    String cloudPackRestoreWrapKind) {}
