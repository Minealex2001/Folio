package com.folio.backend.community.dto;

public record CommunityTemplateRequest(
    String id,
    String name,
    String description,
    String category,
    String emoji,
    Integer blockCount,
    String storagePath,
    String storageDownloadUrl,
    Long sizeBytes) {}
