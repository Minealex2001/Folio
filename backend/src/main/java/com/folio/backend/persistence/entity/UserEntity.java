package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "users")
public class UserEntity {

  @Id
  @Column(name = "id", nullable = false)
  private String id;

  @Column(name = "email", nullable = false)
  private String email;

  @Column(name = "display_name")
  private String displayName;

  @Column(name = "password_hash", nullable = false)
  private String passwordHash;

  @Column(name = "email_verified_at")
  private Instant emailVerifiedAt;

  @Column(name = "status", nullable = false)
  private String status = "active";

  @Column(name = "folio_staff", nullable = false)
  private boolean folioStaff;

  @Column(name = "stripe_customer_id")
  private String stripeCustomerId;

  @Column(name = "deletion_requested_at")
  private Instant deletionRequestedAt;

  @Column(name = "deletion_scheduled_for")
  private Instant deletionScheduledFor;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @PrePersist
  void onCreate() {
    Instant now = Instant.now();
    if (createdAt == null) {
      createdAt = now;
    }
    updatedAt = now;
    if (status == null) {
      status = "active";
    }
  }

  @PreUpdate
  void onUpdate() {
    updatedAt = Instant.now();
  }

  public String getId() {
    return id;
  }

  public void setId(String id) {
    this.id = id;
  }

  public String getEmail() {
    return email;
  }

  public void setEmail(String email) {
    this.email = email;
  }

  public String getDisplayName() {
    return displayName;
  }

  public void setDisplayName(String displayName) {
    this.displayName = displayName;
  }

  public String getPasswordHash() {
    return passwordHash;
  }

  public void setPasswordHash(String passwordHash) {
    this.passwordHash = passwordHash;
  }

  public Instant getEmailVerifiedAt() {
    return emailVerifiedAt;
  }

  public void setEmailVerifiedAt(Instant emailVerifiedAt) {
    this.emailVerifiedAt = emailVerifiedAt;
  }

  public String getStatus() {
    return status;
  }

  public void setStatus(String status) {
    this.status = status;
  }

  public boolean isFolioStaff() {
    return folioStaff;
  }

  public void setFolioStaff(boolean folioStaff) {
    this.folioStaff = folioStaff;
  }

  public String getStripeCustomerId() {
    return stripeCustomerId;
  }

  public void setStripeCustomerId(String stripeCustomerId) {
    this.stripeCustomerId = stripeCustomerId;
  }

  public Instant getDeletionRequestedAt() {
    return deletionRequestedAt;
  }

  public void setDeletionRequestedAt(Instant deletionRequestedAt) {
    this.deletionRequestedAt = deletionRequestedAt;
  }

  public Instant getDeletionScheduledFor() {
    return deletionScheduledFor;
  }

  public void setDeletionScheduledFor(Instant deletionScheduledFor) {
    this.deletionScheduledFor = deletionScheduledFor;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }

  public void setCreatedAt(Instant createdAt) {
    this.createdAt = createdAt;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }

  public void setUpdatedAt(Instant updatedAt) {
    this.updatedAt = updatedAt;
  }
}
