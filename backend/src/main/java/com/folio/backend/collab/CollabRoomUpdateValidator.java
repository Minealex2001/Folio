package com.folio.backend.collab;

import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.CollabRoomEntity;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Translates firestore.rules collabRooms update block (legacy / e2e seal pending / e2e sealed).
 * Each check documents the rule it replaces.
 */
@Component
public class CollabRoomUpdateValidator {

  public enum Mode {
    LEGACY,
    E2E_SEAL,
    E2E_CONTENT
  }

  public record UpdatePayload(
      String title,
      String blocksJson,
      Integer contentVersion,
      String wrappedRoomKey,
      String contentCipher,
      String updatedBy,
      Set<String> changedKeys) {}

  public Mode classify(CollabRoomEntity room) {
    // collabLegacyRoom(): !('e2eV' in resource) || e2eV == 0
    if (room.getE2eV() == 0) {
      return Mode.LEGACY;
    }
    // collabE2eSealPending(): e2eV == 1 && contentVersion == 0
    if (room.getE2eV() == 1 && room.getContentVersion() == 0) {
      return Mode.E2E_SEAL;
    }
    return Mode.E2E_CONTENT;
  }

  public void validate(CollabRoomEntity room, String callerUid, UpdatePayload payload) {
    Mode mode = classify(room);
    Set<String> changed = payload.changedKeys() == null ? Set.of() : payload.changedKeys();

    switch (mode) {
      case LEGACY -> validateLegacy(room, payload, changed);
      case E2E_SEAL -> validateE2eSeal(room, callerUid, payload, changed);
      case E2E_CONTENT -> validateE2eContent(room, payload, changed);
    }
  }

  private void validateLegacy(CollabRoomEntity room, UpdatePayload payload, Set<String> changed) {
    // hasOnly(['title','blocks','contentVersion','updatedAt','updatedBy'])
    if (!Set.of("title", "blocks", "contentVersion", "updatedAt", "updatedBy").containsAll(changed)) {
      deny("legacy room: only title/blocks/contentVersion/updatedAt/updatedBy may change");
    }
    if (payload.title() == null || payload.title().length() > 500) {
      deny("legacy room: title invalid");
    }
    if (payload.blocksJson() == null) {
      deny("legacy room: blocks required");
    }
    if (payload.contentVersion() == null || payload.contentVersion() < room.getContentVersion()) {
      deny("legacy room: contentVersion must be >= current");
    }
  }

  private void validateE2eSeal(
      CollabRoomEntity room, String callerUid, UpdatePayload payload, Set<String> changed) {
    // owner-only seal; hasOnly wrappedRoomKey/contentCipher/contentVersion/updatedAt/updatedBy
    if (!callerUid.equals(room.getOwnerUid())) {
      deny("e2e seal: only owner may seal");
    }
    if (!Set.of("wrappedRoomKey", "contentCipher", "contentVersion", "updatedAt", "updatedBy")
        .containsAll(changed)) {
      deny("e2e seal: illegal field change");
    }
    String key = payload.wrappedRoomKey();
    if (key == null || key.length() < 24 || key.length() > 512) {
      deny("e2e seal: wrappedRoomKey invalid");
    }
    String cipher = payload.contentCipher();
    if (cipher == null || cipher.isEmpty() || cipher.length() > 900_000) {
      deny("e2e seal: contentCipher invalid");
    }
    if (payload.contentVersion() == null || payload.contentVersion() != 1) {
      deny("e2e seal: contentVersion must be 1");
    }
    if (payload.updatedBy() == null || !payload.updatedBy().equals(callerUid)) {
      deny("e2e seal: updatedBy must be caller");
    }
  }

  private void validateE2eContent(CollabRoomEntity room, UpdatePayload payload, Set<String> changed) {
    // wrappedRoomKey immutable; hasOnly contentCipher/contentVersion/updatedAt/updatedBy
    if (!Set.of("contentCipher", "contentVersion", "updatedAt", "updatedBy").containsAll(changed)) {
      deny("e2e content: illegal field change");
    }
    String cipher = payload.contentCipher();
    if (cipher == null || cipher.isEmpty() || cipher.length() > 900_000) {
      deny("e2e content: contentCipher invalid");
    }
    if (payload.contentVersion() == null || payload.contentVersion() <= room.getContentVersion()) {
      deny("e2e content: contentVersion must increase");
    }
  }

  private static void deny(String message) {
    throw new ApiException(HttpStatus.FORBIDDEN, "permission_denied", message);
  }
}
