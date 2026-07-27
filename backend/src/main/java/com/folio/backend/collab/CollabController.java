package com.folio.backend.collab;

import com.folio.backend.collab.dto.CollabInviteRequest;
import com.folio.backend.collab.dto.CollabJoinRequest;
import com.folio.backend.collab.dto.CollabMediaCommitRequest;
import com.folio.backend.collab.dto.CollabMediaPrepareRequest;
import com.folio.backend.collab.dto.CollabRoomUpdateRequest;
import com.folio.backend.collab.dto.CreateCollabRoomRequest;
import com.folio.backend.user.FolioUserPrincipal;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/collab/rooms")
public class CollabController {

  private final CollabService service;

  public CollabController(CollabService service) {
    this.service = service;
  }

  @PostMapping
  public Map<String, Object> create(@RequestBody CreateCollabRoomRequest body) {
    return service.createRoom(FolioUserPrincipal.requireUid(), body.vaultPageId());
  }

  @PostMapping("/join")
  public Map<String, Object> join(@RequestBody CollabJoinRequest body) {
    return service.joinByCode(FolioUserPrincipal.requireUid(), body.joinCode());
  }

  @GetMapping("/{roomId}")
  public Map<String, Object> get(@PathVariable String roomId) {
    return service.getRoom(FolioUserPrincipal.requireUid(), roomId);
  }

  @PutMapping("/{roomId}")
  public Map<String, Object> update(
      @PathVariable String roomId, @RequestBody CollabRoomUpdateRequest body) {
    Set<String> changed = body.changedKeys() == null ? new HashSet<>() : new HashSet<>(body.changedKeys());
    return service.updateRoom(
        FolioUserPrincipal.requireUid(),
        roomId,
        new CollabRoomUpdateValidator.UpdatePayload(
            body.title(),
            body.blocksJson(),
            body.contentVersion(),
            body.wrappedRoomKey(),
            body.contentCipher(),
            body.updatedBy(),
            changed));
  }

  @PostMapping("/{roomId}/media/prepare")
  public Map<String, Object> prepareMedia(
      @PathVariable String roomId, @RequestBody CollabMediaPrepareRequest body) {
    return service.prepareMediaUpload(
        FolioUserPrincipal.requireUid(),
        roomId,
        body.blockId(),
        body.mediaKind(),
        body.sizeBytes() == null ? 0 : body.sizeBytes());
  }

  @PostMapping("/{roomId}/media/commit")
  public Map<String, Object> commitMedia(
      @PathVariable String roomId, @RequestBody CollabMediaCommitRequest body) {
    return service.commitMediaUpload(
        FolioUserPrincipal.requireUid(),
        roomId,
        body.mediaId(),
        body.blockId(),
        body.storagePath(),
        body.mediaKind(),
        body.sizeBytes() == null ? 0 : body.sizeBytes());
  }

  @PostMapping("/{roomId}/invite")
  public Map<String, Object> invite(
      @PathVariable String roomId, @RequestBody CollabInviteRequest body) {
    return service.inviteMember(FolioUserPrincipal.requireUid(), roomId, body.memberUid());
  }

  @PostMapping("/{roomId}/remove-member")
  public Map<String, Object> remove(
      @PathVariable String roomId, @RequestBody CollabInviteRequest body) {
    return service.removeMember(FolioUserPrincipal.requireUid(), roomId, body.memberUid());
  }

  @PostMapping("/{roomId}/close")
  public Map<String, Object> close(@PathVariable String roomId) {
    return service.closeRoom(FolioUserPrincipal.requireUid(), roomId);
  }
}
