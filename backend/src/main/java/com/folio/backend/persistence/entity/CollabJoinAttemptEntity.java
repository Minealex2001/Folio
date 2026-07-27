package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "collab_join_attempts")
public class CollabJoinAttemptEntity {
  @Id @Column(name = "uid", nullable = false) private String uid;
  @Column(name = "attempt_count", nullable = false) private int attemptCount;
  @Column(name = "window_started_at", nullable = false) private Instant windowStartedAt;
  public String getUid() { return uid; } public void setUid(String uid) { this.uid = uid; }
  public int getAttemptCount() { return attemptCount; } public void setAttemptCount(int attemptCount) { this.attemptCount = attemptCount; }
  public Instant getWindowStartedAt() { return windowStartedAt; } public void setWindowStartedAt(Instant windowStartedAt) { this.windowStartedAt = windowStartedAt; }
}
