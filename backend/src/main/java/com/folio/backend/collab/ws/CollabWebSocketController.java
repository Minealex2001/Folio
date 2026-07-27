package com.folio.backend.collab.ws;

import com.folio.backend.collab.CollabRoomUpdateValidator;
import com.folio.backend.collab.CollabService;
import com.folio.backend.collab.dto.CollabRoomUpdateRequest;
import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.CollabRoomEntity;
import com.folio.backend.persistence.repository.CollabRoomRepository;
import java.security.Principal;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageExceptionHandler;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.messaging.simp.annotation.SendToUser;
import org.springframework.stereotype.Controller;

/**
 * Transporte STOMP de sync de contenido (Fase 27). Valida con {@link CollabRoomUpdateValidator} vía
 * {@link CollabService#updateRoom}, persiste {@code content_version} y retransmite solo si es válido.
 */
@Controller
public class CollabWebSocketController {

  private final CollabService collabService;
  private final CollabRoomRepository roomRepository;
  private final SimpMessagingTemplate messagingTemplate;

  public CollabWebSocketController(
      CollabService collabService,
      CollabRoomRepository roomRepository,
      SimpMessagingTemplate messagingTemplate) {
    this.collabService = collabService;
    this.roomRepository = roomRepository;
    this.messagingTemplate = messagingTemplate;
  }

  @MessageMapping("/collab/{roomId}/update")
  public void updateRoom(
      @DestinationVariable String roomId,
      @Payload CollabRoomUpdateRequest body,
      Principal principal) {
    String uid = principal.getName();
    Set<String> changed =
        body.changedKeys() == null ? new HashSet<>() : new HashSet<>(body.changedKeys());
    CollabRoomUpdateValidator.UpdatePayload payload =
        new CollabRoomUpdateValidator.UpdatePayload(
            body.title(),
            body.blocksJson(),
            body.contentVersion(),
            body.wrappedRoomKey(),
            body.contentCipher(),
            body.updatedBy(),
            changed);
    collabService.updateRoom(uid, roomId, payload);

    CollabRoomEntity room =
        roomRepository
            .findById(UUID.fromString(roomId))
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "Room not found"));
    Map<String, Object> snapshot = new LinkedHashMap<>();
    snapshot.put("roomId", room.getId().toString());
    snapshot.put("e2eV", (int) room.getE2eV());
    snapshot.put("contentVersion", room.getContentVersion());
    snapshot.put("title", room.getTitle());
    snapshot.put("blocks", room.getBlocks());
    snapshot.put("wrappedRoomKey", room.getWrappedRoomKey());
    snapshot.put("contentCipher", room.getContentCipher());
    snapshot.put("updatedBy", room.getUpdatedBy());

    messagingTemplate.convertAndSend(
        "/topic/collab/" + roomId, CollabRoomSyncPayload.fromRoomSnapshot(snapshot).toMap());
  }

  @MessageExceptionHandler(ApiException.class)
  @SendToUser("/queue/collab-errors")
  public Map<String, String> onApiException(ApiException ex) {
    return Map.of(
        "error", ex.getCode() != null ? ex.getCode() : "error",
        "message", ex.getMessage() != null ? ex.getMessage() : "rejected");
  }
}
