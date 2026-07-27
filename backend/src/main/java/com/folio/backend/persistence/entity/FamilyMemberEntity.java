package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;

@Entity
@Table(name = "family_members")
public class FamilyMemberEntity {

  @EmbeddedId private FamilyMemberId id;

  @Column(name = "email_snapshot")
  private String emailSnapshot;

  @Column(name = "display_name_snapshot")
  private String displayNameSnapshot;

  @Column(name = "joined_at", nullable = false)
  private Instant joinedAt;

  @PrePersist
  void onCreate() {
    if (joinedAt == null) {
      joinedAt = Instant.now();
    }
  }

  public FamilyMemberId getId() {
    return id;
  }

  public void setId(FamilyMemberId id) {
    this.id = id;
  }

  public String getEmailSnapshot() {
    return emailSnapshot;
  }

  public void setEmailSnapshot(String emailSnapshot) {
    this.emailSnapshot = emailSnapshot;
  }

  public String getDisplayNameSnapshot() {
    return displayNameSnapshot;
  }

  public void setDisplayNameSnapshot(String displayNameSnapshot) {
    this.displayNameSnapshot = displayNameSnapshot;
  }

  public Instant getJoinedAt() {
    return joinedAt;
  }

  public void setJoinedAt(Instant joinedAt) {
    this.joinedAt = joinedAt;
  }

  @Embeddable
  public static class FamilyMemberId implements Serializable {
    @Column(name = "family_owner_uid", nullable = false)
    private String familyOwnerUid;

    @Column(name = "member_uid", nullable = false)
    private String memberUid;

    public FamilyMemberId() {}

    public FamilyMemberId(String familyOwnerUid, String memberUid) {
      this.familyOwnerUid = familyOwnerUid;
      this.memberUid = memberUid;
    }

    public String getFamilyOwnerUid() {
      return familyOwnerUid;
    }

    public void setFamilyOwnerUid(String familyOwnerUid) {
      this.familyOwnerUid = familyOwnerUid;
    }

    public String getMemberUid() {
      return memberUid;
    }

    public void setMemberUid(String memberUid) {
      this.memberUid = memberUid;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof FamilyMemberId that)) return false;
      return Objects.equals(familyOwnerUid, that.familyOwnerUid)
          && Objects.equals(memberUid, that.memberUid);
    }

    @Override
    public int hashCode() {
      return Objects.hash(familyOwnerUid, memberUid);
    }
  }
}
