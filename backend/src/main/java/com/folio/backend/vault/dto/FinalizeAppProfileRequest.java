package com.folio.backend.vault.dto;

import java.util.List;

public record FinalizeAppProfileRequest(
    String packStoragePath,
    Long packSizeBytes,
    String contentFingerprint,
    String restoreWrapB64,
    List<String> iconIds) {}
