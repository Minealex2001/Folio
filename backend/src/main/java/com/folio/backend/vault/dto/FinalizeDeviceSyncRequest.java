package com.folio.backend.vault.dto;

import java.util.List;

public record FinalizeDeviceSyncRequest(
    String vaultId,
    Integer syncFormatVersion,
    String contentFingerprint,
    String packStoragePath,
    Long packSizeBytes,
    String manifestStoragePath,
    Long manifestSizeBytes,
    String oldPackStoragePath,
    Long oldPackSizeBytes,
    String oldManifestStoragePath,
    Long oldManifestSizeBytes,
    List<BlobSizeDto> newBlobs,
    List<BlobSizeDto> deleteBlobs,
    String deviceId,
    String deviceName,
    String vaultMode,
    String packKeyKind,
    String dekAccountWrapB64) {}
