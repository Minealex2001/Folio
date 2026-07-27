package com.folio.backend.collab.dto;
import java.util.List;
public record CollabRoomUpdateRequest(
    String title, String blocksJson, Integer contentVersion,
    String wrappedRoomKey, String contentCipher, String updatedBy, List<String> changedKeys) {}
