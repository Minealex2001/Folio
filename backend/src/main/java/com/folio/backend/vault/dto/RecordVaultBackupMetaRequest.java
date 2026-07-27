package com.folio.backend.vault.dto;

public record RecordVaultBackupMetaRequest(
    String vaultId, String storagePath, Long sizeBytes, String contentFingerprint) {}
