package com.folio.backend.collab;

import com.folio.backend.common.ApiException;
import com.folio.backend.persistence.entity.CollabJoinAttemptEntity;
import com.folio.backend.persistence.entity.CollabRoomEntity;
import com.folio.backend.persistence.entity.CollabRoomMediaEntity;
import com.folio.backend.persistence.entity.CollabRoomMemberEntity;
import com.folio.backend.persistence.repository.CollabJoinAttemptRepository;
import com.folio.backend.persistence.repository.CollabRoomMediaRepository;
import com.folio.backend.persistence.repository.CollabRoomMemberRepository;
import com.folio.backend.persistence.repository.CollabRoomRepository;
import com.folio.backend.storage.CollabMembershipLookup;
import com.folio.backend.storage.FolioCloudFeatureGate;
import com.folio.backend.storage.StoragePathAuthorizer;
import com.folio.backend.storage.StorageService;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CollabService implements CollabMembershipLookup {

  public static final int MAX_MEMBERS = 24;
  public static final long MEDIA_MAX_BYTES = StoragePathAuthorizer.COLLAB_MEDIA_MAX_BYTES;
  private static final int JOIN_MAX_ATTEMPTS = 8;
  private static final Duration JOIN_WINDOW = Duration.ofMinutes(5);
  private static final Set<String> MEDIA_KINDS = Set.of("image", "video", "audio", "file");
  private static final String[] JOIN_EMOJIS = {
    "\uD83C\uDF31", "\u2B50", "\uD83C\uDF19", "\uD83D\uDD25", "\uD83C\uDF08"
  };

  private final CollabRoomRepository roomRepository;
  private final CollabRoomMemberRepository memberRepository;
  private final CollabRoomMediaRepository mediaRepository;
  private final CollabJoinAttemptRepository joinAttemptRepository;
  private final FolioCloudFeatureGate featureGate;
  private final CollabRoomUpdateValidator updateValidator;
  private final StoragePathAuthorizer pathAuthorizer;
  private final StorageService storageService;
  private final SecureRandom secureRandom = new SecureRandom();

  public CollabService(
      CollabRoomRepository roomRepository,
      CollabRoomMemberRepository memberRepository,
      CollabRoomMediaRepository mediaRepository,
      CollabJoinAttemptRepository joinAttemptRepository,
      FolioCloudFeatureGate featureGate,
      CollabRoomUpdateValidator updateValidator,
      StoragePathAuthorizer pathAuthorizer,
      StorageService storageService) {
    this.roomRepository = roomRepository;
    this.memberRepository = memberRepository;
    this.mediaRepository = mediaRepository;
    this.joinAttemptRepository = joinAttemptRepository;
    this.featureGate = featureGate;
    this.updateValidator = updateValidator;
    this.pathAuthorizer = pathAuthorizer;
    this.storageService = storageService;
  }

  @Override
  public boolean isMember(String roomId, String uid) {
    try {
      UUID id = UUID.fromString(roomId);
      CollabRoomEntity room = roomRepository.findById(id).orElse(null);
      if (room == null) {
        return false;
      }
      return room.getOwnerUid().equals(uid) || memberRepository.existsByRoomIdAndMemberUid(id, uid);
    } catch (IllegalArgumentException e) {
      return false;
    }
  }

  private void requireCollab(String uid) {
    if (!featureGate.realtimeCollabOk(uid)) {
      throw new ApiException(
          HttpStatus.FORBIDDEN,
          "permission_denied",
          "Real-time collaboration is not enabled for this account.");
    }
  }

  @Transactional
  public Map<String, Object> createRoom(String uid, String vaultPageIdRaw) {
    requireCollab(uid);
    String vaultPageId = vaultPageIdRaw == null ? "" : vaultPageIdRaw.trim();
    if (vaultPageId.isEmpty() || vaultPageId.length() > 128) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "vaultPageId invalid");
    }
    for (int attempt = 0; attempt < 28; attempt++) {
      String joinCode = generateJoinCode();
      String key = joinCodeKey(normalizeJoinCode(joinCode));
      if (roomRepository.existsByJoinCodeKey(key)) {
        continue;
      }
      CollabRoomEntity room = new CollabRoomEntity();
      room.setOwnerUid(uid);
      room.setVaultPageId(vaultPageId);
      room.setJoinCodeKey(key);
      room.setJoinCode(joinCode);
      room.setE2eV((short) 1);
      room.setContentVersion(0);
      roomRepository.save(room);
      CollabRoomMemberEntity member = new CollabRoomMemberEntity();
      member.setRoomId(room.getId());
      member.setMemberUid(uid);
      memberRepository.save(member);
      return Map.of("roomId", room.getId().toString(), "joinCode", joinCode);
    }
    throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "internal", "Could not allocate join code");
  }

  @Transactional
  public Map<String, Object> joinByCode(String uid, String joinCodeRaw) {
    requireCollab(uid);
    recordJoinAttempt(uid);
    String raw = joinCodeRaw == null ? "" : joinCodeRaw.trim();
    if (raw.length() < 4 || raw.length() > 64) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Invalid join code");
    }
    String key = joinCodeKey(normalizeJoinCode(raw));
    CollabRoomEntity room =
        roomRepository
            .findByJoinCodeKey(key)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "Room not found"));
    if (!memberRepository.existsByRoomIdAndMemberUid(room.getId(), uid)) {
      if (memberRepository.countByRoomId(room.getId()) >= MAX_MEMBERS) {
        throw new ApiException(HttpStatus.PRECONDITION_FAILED, "failed_precondition", "Room is full");
      }
      CollabRoomMemberEntity m = new CollabRoomMemberEntity();
      m.setRoomId(room.getId());
      m.setMemberUid(uid);
      memberRepository.save(m);
    }
    joinAttemptRepository.deleteById(uid);
    return Map.of("roomId", room.getId().toString());
  }

  @Transactional(readOnly = true)
  public Map<String, Object> prepareMediaUpload(
      String uid, String roomIdRaw, String blockId, String mediaKind, long sizeBytes) {
    requireCollab(uid);
    UUID roomId = parseRoomId(roomIdRaw);
    requireMember(roomId, uid);
    CollabRoomEntity room = roomRepository.findById(roomId).orElseThrow();
    if (room.getE2eV() != 1) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED, "failed_precondition", "Room must be e2eV=1");
    }
    if (blockId == null || blockId.isBlank() || blockId.length() > 128) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "blockId invalid");
    }
    if (!MEDIA_KINDS.contains(mediaKind == null ? "" : mediaKind.trim())) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "mediaKind invalid");
    }
    if (sizeBytes <= 0 || sizeBytes > MEDIA_MAX_BYTES) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "sizeBytes invalid");
    }
    UUID mediaId = UUID.randomUUID();
    String storagePath = "collab-media-e2e/" + roomId + "/" + mediaId;
    pathAuthorizer.assertWrite(uid, storagePath, sizeBytes);
    String uploadUrl = storageService.presignUpload(storagePath, Duration.ofMinutes(15), sizeBytes);
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("mediaId", mediaId.toString());
    out.put("storagePath", storagePath);
    out.put("roomId", roomId.toString());
    out.put("blockId", blockId.trim());
    out.put("mediaKind", mediaKind.trim());
    out.put("uploadUrl", uploadUrl);
    return out;
  }

  @Transactional
  public Map<String, Object> commitMediaUpload(
      String uid,
      String roomIdRaw,
      String mediaIdRaw,
      String blockId,
      String storagePath,
      String mediaKind,
      long sizeBytes) {
    requireCollab(uid);
    UUID roomId = parseRoomId(roomIdRaw);
    requireMember(roomId, uid);
    if (mediaIdRaw == null || blockId == null || storagePath == null || mediaKind == null) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Missing required media fields");
    }
    UUID mediaId = UUID.fromString(mediaIdRaw.trim());
    String expected = "collab-media-e2e/" + roomId + "/" + mediaId;
    if (!storagePath.trim().startsWith(expected)) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "storagePath invalid");
    }
    if (!MEDIA_KINDS.contains(mediaKind.trim())) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "mediaKind invalid");
    }
    if (sizeBytes <= 0 || sizeBytes > MEDIA_MAX_BYTES) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "sizeBytes invalid");
    }
    pathAuthorizer.assertWrite(uid, storagePath.trim(), sizeBytes);
    CollabRoomMediaEntity media = new CollabRoomMediaEntity();
    media.setId(mediaId);
    media.setRoomId(roomId);
    media.setBlockId(blockId.trim());
    media.setStoragePath(storagePath.trim());
    media.setMediaKind(mediaKind.trim());
    media.setSizeBytes(sizeBytes);
    media.setE2eV((short) 1);
    mediaRepository.save(media);
    return Map.of("ok", true, "mediaId", mediaId.toString());
  }

  @Transactional
  public Map<String, Object> inviteMember(String uid, String roomIdRaw, String memberUid) {
    requireCollab(uid);
    UUID roomId = parseRoomId(roomIdRaw);
    CollabRoomEntity room = requireOwner(roomId, uid);
    if (memberUid == null || memberUid.isBlank()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "memberUid required");
    }
    if (memberRepository.countByRoomId(roomId) >= MAX_MEMBERS) {
      throw new ApiException(
          HttpStatus.PRECONDITION_FAILED,
          "failed_precondition",
          "Room has at most " + MAX_MEMBERS + " members");
    }
    if (!memberRepository.existsByRoomIdAndMemberUid(roomId, memberUid.trim())) {
      CollabRoomMemberEntity m = new CollabRoomMemberEntity();
      m.setRoomId(roomId);
      m.setMemberUid(memberUid.trim());
      memberRepository.save(m);
    }
    room.setUpdatedAt(Instant.now());
    roomRepository.save(room);
    return Map.of("ok", true);
  }

  @Transactional
  public Map<String, Object> removeMember(String uid, String roomIdRaw, String memberUid) {
    requireCollab(uid);
    UUID roomId = parseRoomId(roomIdRaw);
    CollabRoomEntity room = requireOwner(roomId, uid);
    if (memberUid == null || memberUid.isBlank() || memberUid.equals(room.getOwnerUid())) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "Cannot remove owner");
    }
    memberRepository.deleteByRoomIdAndMemberUid(roomId, memberUid.trim());
    return Map.of("ok", true);
  }

  @Transactional
  public Map<String, Object> closeRoom(String uid, String roomIdRaw) {
    requireCollab(uid);
    UUID roomId = parseRoomId(roomIdRaw);
    requireOwner(roomId, uid);
    for (CollabRoomMediaEntity m : mediaRepository.findByRoomId(roomId)) {
      // storage rules: no delete of collab media; purge prefix best-effort for owner close
      try {
        storageService.delete(m.getStoragePath());
      } catch (Exception ignored) {
      }
    }
    mediaRepository.deleteByRoomId(roomId);
    memberRepository.deleteByRoomId(roomId);
    roomRepository.deleteById(roomId);
    return Map.of("ok", true);
  }

  @Transactional
  public Map<String, Object> updateRoom(
      String uid, String roomIdRaw, CollabRoomUpdateValidator.UpdatePayload payload) {
    requireCollab(uid);
    UUID roomId = parseRoomId(roomIdRaw);
    requireMember(roomId, uid);
    CollabRoomEntity room = roomRepository.findById(roomId).orElseThrow();
    updateValidator.validate(room, uid, payload);
    CollabRoomUpdateValidator.Mode mode = updateValidator.classify(room);
    switch (mode) {
      case LEGACY -> {
        room.setTitle(payload.title());
        room.setBlocks(payload.blocksJson());
        room.setContentVersion(payload.contentVersion());
        room.setUpdatedBy(payload.updatedBy());
      }
      case E2E_SEAL -> {
        room.setWrappedRoomKey(payload.wrappedRoomKey());
        room.setContentCipher(payload.contentCipher());
        room.setContentVersion(1);
        room.setUpdatedBy(uid);
      }
      case E2E_CONTENT -> {
        room.setContentCipher(payload.contentCipher());
        room.setContentVersion(payload.contentVersion());
        room.setUpdatedBy(payload.updatedBy());
      }
    }
    roomRepository.save(room);
    return Map.of("ok", true, "contentVersion", room.getContentVersion());
  }

  @Transactional(readOnly = true)
  public Map<String, Object> getRoom(String uid, String roomIdRaw) {
    UUID roomId = parseRoomId(roomIdRaw);
    requireMember(roomId, uid);
    CollabRoomEntity room = roomRepository.findById(roomId).orElseThrow();
    List<String> members =
        memberRepository.findByRoomId(roomId).stream()
            .map(CollabRoomMemberEntity::getMemberUid)
            .toList();
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("roomId", room.getId().toString());
    out.put("ownerUid", room.getOwnerUid());
    out.put("vaultPageId", room.getVaultPageId());
    out.put("e2eV", (int) room.getE2eV());
    out.put("contentVersion", room.getContentVersion());
    out.put("memberUids", members);
    out.put("title", room.getTitle());
    out.put("wrappedRoomKey", room.getWrappedRoomKey());
    out.put("contentCipher", room.getContentCipher());
    return out;
  }

  private void recordJoinAttempt(String uid) {
    Instant now = Instant.now();
    CollabJoinAttemptEntity e =
        joinAttemptRepository
            .findById(uid)
            .orElseGet(
                () -> {
                  CollabJoinAttemptEntity n = new CollabJoinAttemptEntity();
                  n.setUid(uid);
                  n.setAttemptCount(0);
                  n.setWindowStartedAt(now);
                  return n;
                });
    if (Duration.between(e.getWindowStartedAt(), now).compareTo(JOIN_WINDOW) > 0) {
      e.setWindowStartedAt(now);
      e.setAttemptCount(1);
    } else {
      if (e.getAttemptCount() >= JOIN_MAX_ATTEMPTS) {
        throw new ApiException(
            HttpStatus.TOO_MANY_REQUESTS,
            "resource_exhausted",
            "Too many join code attempts. Try again later.");
      }
      e.setAttemptCount(e.getAttemptCount() + 1);
    }
    joinAttemptRepository.save(e);
  }

  private CollabRoomEntity requireOwner(UUID roomId, String uid) {
    CollabRoomEntity room =
        roomRepository
            .findById(roomId)
            .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "not_found", "Room not found"));
    if (!room.getOwnerUid().equals(uid)) {
      throw new ApiException(HttpStatus.FORBIDDEN, "permission_denied", "Not room owner");
    }
    return room;
  }

  private void requireMember(UUID roomId, String uid) {
    if (!isMember(roomId.toString(), uid)) {
      throw new ApiException(HttpStatus.FORBIDDEN, "permission_denied", "Not a room member");
    }
  }

  private static UUID parseRoomId(String raw) {
    try {
      return UUID.fromString(raw == null ? "" : raw.trim());
    } catch (Exception e) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_argument", "roomId invalid");
    }
  }

  private String generateJoinCode() {
    // ASCII join codes keep lookup deterministic across JSON round-trips (emojis remain client UX).
    char a = (char) ('A' + secureRandom.nextInt(26));
    char b = (char) ('A' + secureRandom.nextInt(26));
    String n = String.format("%06d", secureRandom.nextInt(1_000_000));
    return "" + a + b + n;
  }

  private static String normalizeJoinCode(String code) {
    return code.replaceAll("\\s+", "");
  }

  private static String joinCodeKey(String normalized) {
    try {
      MessageDigest md = MessageDigest.getInstance("SHA-256");
      byte[] dig = md.digest(normalized.getBytes(StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(dig);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }
}
