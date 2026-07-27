package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "user_folio_cloud")
public class UserFolioCloudEntity {

  @Id
  @Column(name = "user_id", nullable = false)
  private String userId;

  @Column(name = "subscription_status")
  private String subscriptionStatus;

  @Column(name = "active", nullable = false)
  private boolean active;

  @Column(name = "subscription_price_id")
  private String subscriptionPriceId;

  @Column(name = "is_family", nullable = false)
  private boolean family;

  @Column(name = "is_student", nullable = false)
  private boolean student;

  @Column(name = "student_verified", nullable = false)
  private boolean studentVerified;

  @Column(name = "family_owner_uid")
  private String familyOwnerUid;

  @Column(name = "family_seats", nullable = false)
  private int familySeats;

  @JdbcTypeCode(SqlTypes.JSON)
  @Column(name = "features", nullable = false, columnDefinition = "jsonb")
  private String features = "{}";

  /** When true, recompute keeps full Folio Cloud features (QA / admin grant, no Stripe). */
  @Column(name = "admin_override", nullable = false)
  private boolean adminOverride;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @PrePersist
  @PreUpdate
  void touch() {
    updatedAt = Instant.now();
    if (features == null) {
      features = "{}";
    }
  }

  public static UserFolioCloudEntity defaultsFor(String userId) {
    UserFolioCloudEntity e = new UserFolioCloudEntity();
    e.userId = userId;
    e.active = false;
    e.family = false;
    e.student = false;
    e.studentVerified = false;
    e.familySeats = 0;
    e.features = "{}";
    e.adminOverride = false;
    return e;
  }

  public String getUserId() {
    return userId;
  }

  public void setUserId(String userId) {
    this.userId = userId;
  }

  public String getSubscriptionStatus() {
    return subscriptionStatus;
  }

  public void setSubscriptionStatus(String subscriptionStatus) {
    this.subscriptionStatus = subscriptionStatus;
  }

  public boolean isActive() {
    return active;
  }

  public void setActive(boolean active) {
    this.active = active;
  }

  public String getSubscriptionPriceId() {
    return subscriptionPriceId;
  }

  public void setSubscriptionPriceId(String subscriptionPriceId) {
    this.subscriptionPriceId = subscriptionPriceId;
  }

  public boolean isFamily() {
    return family;
  }

  public void setFamily(boolean family) {
    this.family = family;
  }

  public boolean isStudent() {
    return student;
  }

  public void setStudent(boolean student) {
    this.student = student;
  }

  public boolean isStudentVerified() {
    return studentVerified;
  }

  public void setStudentVerified(boolean studentVerified) {
    this.studentVerified = studentVerified;
  }

  public String getFamilyOwnerUid() {
    return familyOwnerUid;
  }

  public void setFamilyOwnerUid(String familyOwnerUid) {
    this.familyOwnerUid = familyOwnerUid;
  }

  public int getFamilySeats() {
    return familySeats;
  }

  public void setFamilySeats(int familySeats) {
    this.familySeats = familySeats;
  }

  public String getFeatures() {
    return features;
  }

  public void setFeatures(String features) {
    this.features = features;
  }

  public boolean isAdminOverride() {
    return adminOverride;
  }

  public void setAdminOverride(boolean adminOverride) {
    this.adminOverride = adminOverride;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }

  public void setUpdatedAt(Instant updatedAt) {
    this.updatedAt = updatedAt;
  }
}
