package com.folio.backend.diagnostics;

import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/diagnostics")
public class DiagnosticsController {

  private final DiagnosticsService service;

  public DiagnosticsController(DiagnosticsService service) {
    this.service = service;
  }

  @PostMapping("/report")
  public ResponseEntity<Map<String, Object>> report(@RequestBody Map<String, Object> body) {
    return service.report(body);
  }
}
