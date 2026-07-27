package com.folio.backend.vault.dto;

public record UpsertVaultBackupIndexRequest(
    String vaultId, String latestStoragePath, Long latestSizeBytes, String contentFingerprint) {}
