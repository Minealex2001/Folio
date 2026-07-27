package com.folio.backend.diagnostics;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "folio_diagnostics")
public class FolioDiagnosticEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private UUID id;

  @Column(name = "install_id", nullable = false)
  private String installId;

  @Column(nullable = false)
  private String kind;

  @Column(name = "app_version")
  private String appVersion;

  private String platform;
  private String channel;

  @Column(name = "user_note")
  private String userNote;

  @Column(name = "log_excerpt")
  private String logExcerpt;

  private String signature;

  @Column(name = "telemetry_enabled", nullable = false)
  private boolean telemetryEnabled;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @PrePersist
  void onCreate() {
    if (createdAt == null) {
      createdAt = Instant.now();
    }
  }

  public UUID getId() {
    return id;
  }

  public String getInstallId() {
    return installId;
  }

  public void setInstallId(String installId) {
    this.installId = installId;
  }

  public void setKind(String kind) {
    this.kind = kind;
  }

  public void setAppVersion(String appVersion) {
    this.appVersion = appVersion;
  }

  public void setPlatform(String platform) {
    this.platform = platform;
  }

  public void setChannel(String channel) {
    this.channel = channel;
  }

  public void setUserNote(String userNote) {
    this.userNote = userNote;
  }

  public void setLogExcerpt(String logExcerpt) {
    this.logExcerpt = logExcerpt;
  }

  public void setSignature(String signature) {
    this.signature = signature;
  }

  public void setTelemetryEnabled(boolean telemetryEnabled) {
    this.telemetryEnabled = telemetryEnabled;
  }
}
