package com.folio.backend.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "stripe_processed_checkouts")
public class StripeProcessedCheckoutEntity {

  @Id
  @Column(name = "session_id", nullable = false)
  private String sessionId;

  @Column(name = "processed_at", nullable = false)
  private Instant processedAt;

  @PrePersist
  void onCreate() {
    if (processedAt == null) {
      processedAt = Instant.now();
    }
  }

  public String getSessionId() {
    return sessionId;
  }

  public void setSessionId(String sessionId) {
    this.sessionId = sessionId;
  }

  public Instant getProcessedAt() {
    return processedAt;
  }

  public void setProcessedAt(Instant processedAt) {
    this.processedAt = processedAt;
  }
}
