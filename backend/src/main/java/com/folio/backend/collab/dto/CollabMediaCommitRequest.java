package com.folio.backend.collab.dto;
public record CollabMediaCommitRequest(
    String mediaId, String blockId, String storagePath, String mediaKind, Long sizeBytes) {}
