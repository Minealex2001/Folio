package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

@Entity
@Table(name = "collab_room_members")
@IdClass(CollabRoomMemberEntity.Pk.class)
public class CollabRoomMemberEntity {
  @Id @Column(name = "room_id", nullable = false) private UUID roomId;
  @Id @Column(name = "member_uid", nullable = false) private String memberUid;
  @Column(name = "joined_at", nullable = false) private Instant joinedAt;
  @PrePersist void onCreate() { if (joinedAt == null) joinedAt = Instant.now(); }
  public static class Pk implements Serializable {
    private UUID roomId; private String memberUid;
    public Pk() {}
    public Pk(UUID r, String u) { roomId = r; memberUid = u; }
    @Override public boolean equals(Object o) { if (this == o) return true; if (!(o instanceof Pk pk)) return false; return Objects.equals(roomId, pk.roomId) && Objects.equals(memberUid, pk.memberUid); }
    @Override public int hashCode() { return Objects.hash(roomId, memberUid); }
  }
  public UUID getRoomId() { return roomId; } public void setRoomId(UUID roomId) { this.roomId = roomId; }
  public String getMemberUid() { return memberUid; } public void setMemberUid(String memberUid) { this.memberUid = memberUid; }
  public Instant getJoinedAt() { return joinedAt; } public void setJoinedAt(Instant joinedAt) { this.joinedAt = joinedAt; }
}
