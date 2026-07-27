package com.folio.backend.diagnostics;

import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DiagnosticsService {

  private static final Logger log = LoggerFactory.getLogger(DiagnosticsService.class);

  private final FolioDiagnosticRepository repository;

  public DiagnosticsService(FolioDiagnosticRepository repository) {
    this.repository = repository;
  }

  @Transactional
  public ResponseEntity<Map<String, Object>> report(Map<String, Object> raw) {
    String installId = slice(str(raw.get("installId")), 120);
    if (installId.isEmpty()) {
      return ResponseEntity.badRequest().body(Map.of("error", "missing_install_id"));
    }
    try {
      FolioDiagnosticEntity e = new FolioDiagnosticEntity();
      e.setInstallId(installId);
      e.setKind(slice(str(raw.get("kind")).isEmpty() ? "manual" : str(raw.get("kind")), 64));
      e.setAppVersion(slice(str(raw.get("appVersion")), 64));
      e.setPlatform(slice(str(raw.get("platform")), 64));
      e.setChannel(slice(str(raw.get("channel")), 64));
      e.setUserNote(slice(str(raw.get("userNote")), 2000));
      e.setLogExcerpt(slice(str(raw.get("logExcerpt")), 12000));
      e.setSignature(slice(str(raw.get("signature")), 128));
      e.setTelemetryEnabled(Boolean.TRUE.equals(raw.get("telemetryEnabled")) || "true".equalsIgnoreCase(str(raw.get("telemetryEnabled"))));
      repository.save(e);
      log.info(
          "diagnostic report installId={} kind={} platform={} version={}",
          installId,
          slice(str(raw.get("kind")).isEmpty() ? "manual" : str(raw.get("kind")), 64),
          str(raw.get("platform")),
          str(raw.get("appVersion")));
      // YouTrack sync is optional; without credentials we always persist locally (savedToYouTrack=false).
      return ResponseEntity.ok(Map.of("ok", true, "savedToYouTrack", false));
    } catch (Exception e) {
      log.error("folioReportDiagnostic", e);
      return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of("error", "write_failed"));
    }
  }

  private static String str(Object v) {
    return v == null ? "" : String.valueOf(v).trim();
  }

  private static String slice(String s, int max) {
    if (s.length() <= max) {
      return s;
    }
    return s.substring(0, max);
  }
}
