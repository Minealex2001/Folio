package com.folio.backend.vault.dto;

public record FinalizeVaultProfileRequest(
    String vaultId,
    String packStoragePath,
    Long packSizeBytes,
    String contentFingerprint,
    String restoreWrapB64) {}
