package com.folio.backend.collab.ws;

import java.util.LinkedHashMap;
import java.util.Map;

/** Mensaje retransmitido a suscriptores de {@code /topic/collab/{roomId}} tras un update válido. */
public record CollabRoomSyncPayload(
    String type,
    String roomId,
    int e2eV,
    int contentVersion,
    String title,
    String blocks,
    String wrappedRoomKey,
    String contentCipher,
    String updatedBy) {

  public static final String TYPE_ROOM_UPDATE = "room.update";

  public static CollabRoomSyncPayload fromRoomSnapshot(Map<String, Object> room) {
    return new CollabRoomSyncPayload(
        TYPE_ROOM_UPDATE,
        stringVal(room.get("roomId")),
        intVal(room.get("e2eV")),
        intVal(room.get("contentVersion")),
        stringVal(room.get("title")),
        stringVal(room.get("blocks")),
        stringVal(room.get("wrappedRoomKey")),
        stringVal(room.get("contentCipher")),
        stringVal(room.get("updatedBy")));
  }

  public Map<String, Object> toMap() {
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("type", type);
    out.put("roomId", roomId);
    out.put("e2eV", e2eV);
    out.put("contentVersion", contentVersion);
    out.put("title", title);
    out.put("blocks", blocks);
    out.put("wrappedRoomKey", wrappedRoomKey);
    out.put("contentCipher", contentCipher);
    out.put("updatedBy", updatedBy);
    return out;
  }

  private static String stringVal(Object v) {
    return v == null ? null : String.valueOf(v);
  }

  private static int intVal(Object v) {
    if (v instanceof Number n) {
      return n.intValue();
    }
    return 0;
  }
}
